classdef Car3DGtilt < TemplateCar3D
    properties
    end

    methods
        function obj = Car3DGtilt()
            obj.name = 'Car3DGtilt';
        end

        function obj = initialize(obj, fig)
            obj.my_plot = fig.setItemType(obj, obj.name, 'plot3dcar');
            obj.my_plot.configPlot('Rota��o 3D usando Posi��o angular absoluta');
            obj.data = zeros(1, 3);
        end
    end
end