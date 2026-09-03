function createProjectionFigure( ...
        mapDb, xAxis, yAxis, outputPath, ...
        xLabelText, yLabelText, titleText, climValue)

    fig = figure( ...
        'Color', 'w', ...
        'Visible', 'off', ...
        'Position', [100, 100, 980, 760]);

    cleanupObject = onCleanup(@() closeFigure(fig)); %#ok<NASGU>

    imagesc(xAxis, yAxis, double(mapDb));
    axis xy;

    xlabel(xLabelText);
    ylabel(yLabelText);
    title(titleText, 'Interpreter', 'none');

    colormap(turbo);
    colorbar;

    if ~isempty(climValue)
        caxis(climValue);
    end

    grid on;
    box on;

    exportgraphics(fig, outputPath, 'Resolution', 150);
end


function closeFigure(fig)

    if isgraphics(fig)
        close(fig);
    end
end