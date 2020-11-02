classdef Car3DAcelMag < TemplateLine
    properties
    end

    methods
        function obj = Car3DAcelMag()
            obj.name = 'Car3DAcelMag';
        end

        function obj = initialize(obj, fig)
            obj.my_plot = fig.setItemType(obj.name, 'plot3dcar');
            obj.my_plot.configPlot('Rota��o 3D usando acel e mag');
            obj.data = zeros(1, 3);
        end

        function calculate(obj, tilt)
            obj.data = tilt;
        end

        function update(obj)
            obj.my_plot.rotateWithEuler(obj.data(1), obj.data(2), obj.data(3));
        end
    end
end