classdef Compass < TemplateLine
    properties
    end

    methods
        function obj = Compass()
            obj.name = 'Compass';
        end

        function obj = initialize(obj, fig)
            obj.my_plot = fig.setItemType(obj.name, 'plotcompass');
            obj.my_plot.configPlot('Magnetic Heading SEM compensa��o de tilt');
            obj.data = 0;
        end

        function calculate(obj, H)
            new_data = compass_without_compensation(H);
            obj.data = new_data;
        end

        function update(obj)
            obj.my_plot.rotateCompass(obj.data);
        end
    end
end