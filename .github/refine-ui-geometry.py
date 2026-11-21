from pathlib import Path

def replace(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    assert s.count(old) == 1, (path, old)
    p.write_text(s.replace(old,new,1),encoding='utf-8',newline='\n')

p='uppermachine/+radarui/ProcessingWindow.m'
replace(p,'                baseCfg.measuredSpeed = obj.ReferenceSpeedEdit.Value;\n','                baseCfg.measuredSpeed = obj.ReferenceSpeedEdit.Value;\n                baseCfg.fitSpeedMin = obj.FitSpeedMinEdit.Value;\n                baseCfg.fitSpeedMax = obj.FitSpeedMaxEdit.Value;\n')
replace(p,'            cfg.measuredSpeed = obj.ReferenceSpeedEdit.Value;\n','            cfg.measuredSpeed = obj.ReferenceSpeedEdit.Value;\n            % The UI speed limits constrain BOTH association and unwrapping.\n            % Do not retain hidden unwrap bounds from the original reference.\n            cfg.unwrapSpeedMin = cfg.fitSpeedMin;\n            cfg.unwrapSpeedMax = cfg.fitSpeedMax;\n')
p='scripts/smoke_test_interfaces.m'
replace(p,'    mainCleanup = onCleanup(@() delete(app));','    mainCleanup = onCleanup(@() close(app.UIFigure));')
replace(p,'    win.PerpendicularDistanceEdit.Value = 1;\n','    win.ReferenceSpeedEdit.Value = 800;\n    win.FitSpeedMinEdit.Value = 600;\n    win.FitSpeedMaxEdit.Value = 1000;\n    win.PerpendicularDistanceEdit.Value = 1;\n')
replace(p,'    assert(win.PerpendicularDistanceEdit.Value==1);\n','    assert(win.ReferenceSpeedEdit.Value==800);\n    assert(win.FitSpeedMinEdit.Value==600 && win.FitSpeedMaxEdit.Value==1000);\n    assert(win.PerpendicularDistanceEdit.Value==1);\n')
replace('tests/test_geometryTrack.m','range(track.FittedRadialVelocity_mps)','(max(track.FittedRadialVelocity_mps)-min(track.FittedRadialVelocity_mps))')
replace('uppermachine/+radarui/buildProcessingConfig.m','    % A reference speed is available in the upper machine, so velocity\n    % consistency can safely participate in track association by default.','    % Interface 2 owns the editable reference speed and geometry settings.\n    % These are initial defaults, not speed measurements from interface 1.')
replace('docs/track_fitting.md','- `measuredSpeed`、拟合速度范围、解模糊速度范围：均为沿轨迹速率（正值），不再将其误当作径向速度。','- `measuredSpeed`、拟合速度范围、解模糊速度范围：均为沿轨迹速率（正值），不再将其误当作径向速度。界面2中的速率上下限同时约束轨迹关联和解模糊，不再使用隐藏的旧参考速度范围。')
