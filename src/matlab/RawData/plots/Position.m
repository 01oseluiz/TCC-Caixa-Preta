classdef Position < TemplateLine
    % Calcula Posi��o integrando a Velocidade
    % Usando a Velocidade, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)

    properties
    end

    methods
        function obj = Position()
            obj.name = 'Position';
        end

        function obj = initialize(obj, fig, w_size)
            obj.w_size = w_size;
            obj.my_plot = fig.setItemType(obj, obj.name, 'plotline');
            obj.my_plot.configPlot('Espa�o em metros', 'Amostra', 'metros', {'X', 'Y', 'Z'}, {'r', 'g', 'b'});
            obj.data = zeros(w_size, 3);
        end

        function calculate(obj, velocity, old_velocity, freq_sample)
            new_data = calculate_position(obj.last(), velocity, old_velocity, freq_sample);
            obj.data = [obj.data(2:obj.w_size, :); new_data];
        end
    end
end