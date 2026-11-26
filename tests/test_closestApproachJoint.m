function tests = test_closestApproachJoint
    tests=functiontests(localfunctions);
end

function testConstantRecedingAndLegacyScalarIgnored(testCase)
    [cfg,input,u,v]=fixture(1,0);
    cfg.motionModel="constantVelocity";
    [out,info]=pradar.unwrapTrackVelocity(input,80,99999,cfg);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    verifyEqual(testCase,out.TargetSpeed_mps,v,'AbsTol',1e-8);
    verifyLessThan(testCase,abs(info.closestSpeed-400),0.1);
    verifyTrue(testCase,all(isnan(out.MeasuredSpeedResidual_mps)));
end

function testDecelerationNotPulledBackToClosestSpeed(testCase)
    [cfg,input,u,v]=fixture(1,-10000);
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    verifyEqual(testCase,out.TargetSpeed_mps,v,'AbsTol',1e-8);
    verifyGreaterThan(testCase,max(out.TargetSpeed_mps)-min(out.TargetSpeed_mps),100);
    verifyLessThan(testCase,max(abs(out.ModelTargetSpeed_mps-v)),0.2);
    verifyLessThan(testCase,abs(info.acceleration+10000),30);
end

function testApproachingNegativeRadial(testCase)
    [cfg,input,u,v]=fixture(-1,-5000);
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyTrue(testCase,all(u<0));
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    verifyEqual(testCase,out.TargetSpeed_mps,v,'AbsTol',1e-8);
end

function testCrossingAndUnobservableDirectSpeed(testCase)
    [cfg,input,u,v]=fixture(0,-4000);
    cfg.closestApproachTimeMs=0;
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    center=find(input.Time_ms==0);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,info.closestTimeMs,0,'AbsTol',1e-6);
    verifyTrue(testCase,out.RangeObservationValid(center));
    verifyFalse(testCase,out.GeometryValid(center));
    verifyTrue(testCase,isnan(out.TargetSpeed_mps(center)));
    verifyLessThan(testCase,abs(out.ModelTargetSpeed_mps(center)-400),0.2);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    good=out.GeometryValid;
    verifyEqual(testCase,out.TargetSpeed_mps(good),v(good),'AbsTol',1e-8);
end

function testAutomaticCrossingTime(testCase)
    [cfg,input,u,~]=fixture(0,0);
    input.Time_ms=input.Time_ms+7;
    cfg.motionModel="constantVelocity";
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,info.closestTimeMs,7,'AbsTol',0.01);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
end

function testMissingDopplerAndIrregularTime(testCase)
    [cfg,input,u,v]=fixture(1,-8000);
    input.AliasedVelocity_mps(5:7)=NaN;
    order=[14:18 1:4 8:13 5:7];
    [out,info]=pradar.jointUnwrapTrack(input(order,:),80,cfg);
    verifyTrue(testCase,info.valid);
    good=isfinite(input.AliasedVelocity_mps(order));
    reordered=u(order);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps(good),reordered(good),'AbsTol',1e-8);
    verifyTrue(testCase,all(isnan(out.UnwrappedRadialVelocity_mps(~good))));
    verifyLessThan(testCase,max(abs(out.ModelTargetSpeed_mps-v(order))),0.2);
end

function testReferenceOptional(testCase)
    [cfg,input,u,~]=fixture(1,-7000);
    cfg.useClosestSpeedPrior=false; cfg.measuredSpeed=NaN;
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,info.costComponents.anchor,0);
    verifyTrue(testCase,isnan(info.anchorResidual));
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
end

function testAnchorIsOnePenaltyNotNObservations(testCase)
    [cfg,input,u,~,model]=fixture(1,-7000);
    cfg.measuredSpeed=410; cfg.closestSpeedStd=10;
    t=input.Time_ms*1e-3;
    [~,a]=pradar.jointMotionLoss(model,t,input.Range_m,u,cfg,true);
    idx=1:2:height(input);
    [~,b]=pradar.jointMotionLoss(model,t(idx),input.Range_m(idx),u(idx),cfg,true);
    verifyEqual(testCase,a.anchor,1,'AbsTol',1e-10);
    verifyEqual(testCase,a.anchor,b.anchor,'AbsTol',1e-10);
end

function testDirectGeometryDoesNotClampBelowD(testCase)
    [cfg,input,~,~]=fixture(0,0);
    cfg.closestApproachTimeMs=0; cfg.motionModel="constantVelocity";
    center=find(input.Time_ms==0);
    input.Range_m(center)=cfg.perpendicularDistance-0.001;
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyTrue(testCase,out.RangeObservationValid(center));
    verifyTrue(testCase,isnan(out.TargetSpeed_mps(center)));
    verifyTrue(testCase,isfinite(out.ModelTargetSpeed_mps(center)));
end

function testNoFeasibleAliasIsNotReportedReliable(testCase)
    [cfg,input,~,~]=fixture(1,0);
    cfg.ambiguityNumberMin=0;cfg.ambiguityNumberMax=0;
    [~,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,~info.valid || info.ambiguityUncertain);
    if info.valid, verifyEqual(testCase,info.status,'model-mismatch'); end
end

function testDuplicateTimeRejected(testCase)
    [cfg,input,~,~]=fixture(1,0);input.Time_ms(2)=input.Time_ms(1);
    verifyError(testCase,@()pradar.jointUnwrapTrack(input,80,cfg),'pradar:DuplicateTrackTime');
end

function testMetricsAreNotFullTrackReferenceErrors(testCase)
    [cfg,input,~,~]=fixture(1,-10000);
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    metrics=pradar.computeVelocityMetrics(out,cfg.measuredSpeed,info);
    verifyTrue(testCase,isnan(metrics.rmse)&&isnan(metrics.mae));
    verifyEqual(testCase,metrics.referenceScope,'closest-point-only');
    verifyEqual(testCase,metrics.closestReferenceResidual,info.anchorResidual);
end

function testPhysicalBoundsIndependentOfAnchor(testCase)
    a=radarui.buildProcessingConfig(struct('approxSpeed',400));
    b=radarui.buildProcessingConfig(struct('approxSpeed',1200));
    verifyEqual(testCase,[a.fitSpeedMin a.fitSpeedMax a.unwrapSpeedMin a.unwrapSpeedMax], ...
        [b.fitSpeedMin b.fitSpeedMax b.unwrapSpeedMin b.unwrapSpeedMax]);
end

function testRadialViterbiMatchesBruteForce(testCase)
    cfg=pradar.defaultConfig();cfg.ambiguityNumberMin=-1;cfg.ambiguityNumberMax=1;
    cfg.jointRadialStd=20;
    t=[0;0.001;0.009];alias=[30;-60;45];prediction=[35;105;210];
    [u,k,cost,second]=pradar.radialAliasPath(t,alias,prediction,160,cfg);
    paths=[];values=[];
    for a=-1:1
        for b=-1:1
            for c=-1:1
                ks=[a;b;c];e=alias+160*ks-prediction;
                scale=sqrt(2*cfg.jointRadialStd^2+(cfg.motionAccelerationStd*diff(t)).^2);
                value=sum(pradar.huberLoss(e/cfg.jointRadialStd,cfg.jointHuberDelta)) ...
                    +cfg.jointTransitionWeight*sum(pradar.huberLoss(diff(e)./scale,cfg.jointHuberDelta));
                paths(:,end+1)=ks;values(end+1)=value; %#ok<AGROW>
            end
        end
    end
    [values,order]=sort(values);
    verifyEqual(testCase,cost,values(1),'AbsTol',1e-10);
    verifyEqual(testCase,second.cost,values(2),'AbsTol',1e-10);
    verifyEqual(testCase,k,paths(:,order(1)));
    verifyEqual(testCase,u,alias+160*k);
end

function testEndToEndCandidateAssociationWithDeceleration(testCase)
    [cfg,input,u,~]=fixture(1,-8000);
    cfg.minTrackWindows=5;cfg.trackTolerance=0.15;cfg.jointMaxTrackHypotheses=3;
    cfg.jointMaxStarts=3;cfg.useVelocityHardGate=false;
    n=height(input);idx=(1:n).';
    candidates=table(idx,ones(n,1),idx,input.Time_ms,input.Range_m, ...
        input.AliasedVelocity_mps,25*ones(n,1),ones(n,1), ...
        'VariableNames',{'GlobalWindow','PhysicalFrame','WindowInFrame','Time_ms', ...
        'Range_m','AliasedVelocity_mps','RelativeStrength_dB','RangeBin'});
    weak=candidates;weak.Range_m=weak.Range_m+1;weak.RelativeStrength_dB(:)=4;
    derived=struct('vMax',80,'velocityPeriod',160);
    [track,fit]=pradar.selectTrack([candidates;weak],cfg,derived);
    verifyTrue(testCase,fit.valid);
    verifyEqual(testCase,height(track),n);
    verifyEqual(testCase,track.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    verifyTrue(testCase,all(track.RelativeStrength_dB==25));
end

function testAssociationDoesNotReadGlobalReference(testCase)
    [cfg,input,~,~,model]=fixture(1,-8000);
    n=height(input);c=input;c.GlobalWindow=(1:n).';c.RelativeStrength_dB=25*ones(n,1);
    derived=struct('vMax',80,'velocityPeriod',160);
    [a,score1]=pradar.associateMotionCandidates(c,model,cfg,derived);
    cfg.measuredSpeed=1500;
    [b,score2]=pradar.associateMotionCandidates(c,model,cfg,derived);
    verifyEqual(testCase,a,b);verifyEqual(testCase,score1,score2);
end

function [cfg,input,u,v,model]=fixture(direction,acceleration)
    cfg=pradar.defaultConfig();cfg.measuredSpeed=400;
    cfg.perpendicularDistance=1;cfg.radialDirection=direction;
    cfg.fitSpeedMin=50;cfg.fitSpeedMax=1200;cfg.unwrapSpeedMin=50;cfg.unwrapSpeedMax=1200;
    cfg.jointRangeStd=0.003;cfg.jointRadialStd=0.2;cfg.closestSpeedStd=20;
    cfg.jointMaxStarts=4;cfg.jointMaxIterations=3;
    if direction>0
        t=(1:18).'*0.001;
    elseif direction<0
        t=(-18:-1).'*0.001;
    else
        t=(-9:9).'*0.0007;
    end
    model=struct('timeOrigin',0,'x0',0,'v0',400,'acceleration',acceleration);
    [R,u,v]=pradar.evaluateMotion(t,model,cfg.perpendicularDistance);
    input=table(t*1000,R,pradar.wrapVelocity(u,80), ...
        'VariableNames',{'Time_ms','Range_m','AliasedVelocity_mps'});
end

function testBiasedReferenceDoesNotChangeWholeAliasPath(testCase)
    [cfg,input,u,~]=fixture(1,-10000);
    cfg.measuredSpeed=450; cfg.closestSpeedStd=50;
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    verifyLessThan(testCase,abs(info.closestSpeed-400),1);
    verifyGreaterThan(testCase,max(out.ModelTargetSpeed_mps)-min(out.ModelTargetSpeed_mps),100);
end

function testNoisyMeasurementsAndSingleOutlier(testCase)
    [cfg,input,u,v]=fixture(1,-6000);
    cfg.jointRangeStd=0.02; cfg.jointRadialStd=1;
    n=height(input); z=(1:n).';
    input.Range_m=input.Range_m+0.006*sin(z*1.7);
    input.AliasedVelocity_mps=pradar.wrapVelocity(u+0.2*cos(z),80);
    input.Range_m(9)=input.Range_m(9)+0.12;
    [out,info]=pradar.jointUnwrapTrack(input,80,cfg);
    verifyTrue(testCase,info.valid);
    verifyEqual(testCase,out.UnwrappedRadialVelocity_mps,u+0.2*cos(z),'AbsTol',1e-8);
    verifyLessThan(testCase,max(abs(out.ModelTargetSpeed_mps-v)),5);
end

function testCrossingAssociationRetainsClosestRangePoint(testCase)
    [cfg,input,u,~]=fixture(0,-4000);
    cfg.closestApproachTimeMs=0;cfg.trackStartTimeMs=-Inf;
    cfg.minTrackWindows=5;cfg.trackTolerance=0.15;cfg.jointMaxTrackHypotheses=3;
    cfg.jointMaxStarts=3;cfg.useVelocityHardGate=false;
    n=height(input);idx=(1:n).';
    c=table(idx,ones(n,1),idx,input.Time_ms,input.Range_m,input.AliasedVelocity_mps, ...
        25*ones(n,1),ones(n,1),'VariableNames',{'GlobalWindow','PhysicalFrame', ...
        'WindowInFrame','Time_ms','Range_m','AliasedVelocity_mps','RelativeStrength_dB','RangeBin'});
    [track,fit]=pradar.selectTrack(c,cfg,struct('vMax',80,'velocityPeriod',160));
    verifyTrue(testCase,fit.valid);verifyEqual(testCase,height(track),n);
    verifyEqual(testCase,track.UnwrappedRadialVelocity_mps,u,'AbsTol',1e-8);
    verifyTrue(testCase,isnan(track.TargetSpeed_mps(track.Time_ms==0)));
end
