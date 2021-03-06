classdef Velocity < TemplateLine
    % Calcula Velocidade integrando a Acelera��o
    % Usando a Acelera��o, fazemos a integral discreta (�rea do trap�zio aculmulado)
    % P/ o novo dado isso significa, ultimo valor + novo trap�zio (entre ultimo dado e o novo)
    % � considerado nesse calculo que, as amostragens est�o espa�adas de 1
    % periodo da amostragem, ent o trap�zio � igual a 1/freq * ((n-1 + n)/2)

    properties
    end

    methods
        function obj = Velocity(w_size)
            obj = obj@TemplateLine(...
                'Velocidade em m/s', ...       % p_title
                'Amostra', ...                 % p_xlabel
                'm/s', ...                       % p_ylabel
                {'vX', 'vY', 'vZ'}, ...        % s_legend
                {'r', 'g', 'b'});              % sources_color

            obj.w_size = w_size;
            obj.data = zeros(w_size, 3);
        end

        function calculate(obj, A_without_gravity, old_A_without_gravity, freq_sample, const_g)
            new_data = obj.calculate_velocity(obj.last(), const_g*A_without_gravity, const_g*old_A_without_gravity, freq_sample);
            obj.data = [obj.data(2:obj.w_size, :); new_data];
        end
    end
end