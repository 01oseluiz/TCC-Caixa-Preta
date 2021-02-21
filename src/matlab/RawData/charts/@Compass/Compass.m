classdef Compass < TemplateCompass
    % Calcula Compass sem compensa��o 
    % Ref do calculo: https://blog.digilentinc.com/how-to-convert-magnetometer-data-into-compass-heading/
    % e plota em plano polar o Compass sem compensa��o 

    properties
    end

    methods
        function obj = Compass()
            obj = obj@TemplateCompass('Magnetic Heading SEM compensa��o de tilt');      % p_title
        end

        function obj = initialize(obj, fig)
            obj.data = 0;
        end

        function calculate(obj, H)
            new_data = obj.compass_without_compensation(H);
            obj.data = new_data;
        end
    end
end