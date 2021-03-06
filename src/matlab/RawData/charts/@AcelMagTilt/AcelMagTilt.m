classdef AcelMagTilt < TemplateLine
    % Calcula Yaw, Pitch e Roll absolutos(em rela��o a Posi��o inicial do corpo) p/ a nova amostra usando Acelera��o e Magnet�metro
    % Usando a Acelera��o, usamos o vetor de gravidade que deve sempre
    % estar presente p/ determinar a Posi��o do corpo
    % assim temos que p/ a orderm de Rota��o Z,Y,X (note que na referencia ele faz o calculo com XYZ, isso se deve por conta do lado da equa��o ao qual a matriz aparece)
    % Ref do calculo: https://www.nxp.com/docs/en/application-note/AN3461.pdf

    properties
    end

    methods
        function obj = AcelMagTilt(w_size)
            obj = obj@TemplateLine(...
                'Giro em graus(absoluto) usando acel + mag', ...     % p_title
                'Amostra', ...                                       % p_xlabel
                'graus', ...                                         % p_ylabel
                {'aRoll', 'aPitch', 'mYaw'}, ...                     % s_legend
                {'r', 'g', 'b'});                                    % sources_color
            
            obj.w_size = w_size;
            obj.data = zeros(w_size, 3);
        end
        
        function calculate(obj, A, H)
            new_data = obj.calculate_acel_mag_tilt(A, H);
            obj.data = [obj.data(2:obj.w_size, :); new_data];
        end
    end
end