classdef Kalman < handle
    %KALMAN Summary of this class goes here
    %   Model:
    %   x[k] = A*x[k-1] + B*u[k] + w[k]
    %   y[k] = C*x[k] + v[k]
    %   E[wwt] = Q
    %   E[vvt] = R

    properties
        xk_minus                % x estimado p/ o instante k
        pk_minus                % p estimado p/ o instante k
        xk_1_minus              % x estimado p/ o instante k-1
        pk_1_minus              % p estimado p/ o instante k-1

        K                       % Matriz de ajuste

        Q                       % Erro do valor de entrada
        R                       % Erro do valor de sa�da do Model

        A                       % (Matriz din�mica)
        B                       % (Matriz de entrada)
        C                       % (Matriz de sa�da)
    end
    
    methods
        function obj = Kalman(A,B,C,Q,R)
           obj.A = A;
           obj.B = B;
           obj.C = C;
           obj.Q = Q;
           obj.R = R;

           obj.xk_1_minus = zeros(length(A), 1);
           obj.pk_1_minus = zeros(length(A));
        end

        % Realiza a etapa de predi��o do algoritmo, salvando no objeto os valores preditos, n�o retorna nada e recebe como par�metro a amostra de entrada
        function predict(obj, uk)
            % Calcula x a priori
            obj.xk_minus = obj.A * obj.xk_1_minus + obj.B * uk;

            % Calcula p a priori
            obj.pk_minus = obj.A * obj.pk_1_minus * obj.A' + obj.Q;

            % Atualiza x e k anterior, para o caso de n�o ser utilizado a fun��o de update
            obj.xk_1_minus = obj.xk_minus;
            obj.pk_1_minus = obj.pk_minus;
        end

        % Realiza a etapa de atualiza��o do algoritmo, salvando no objeto e retornando o valor de x, recebe como par�metro a amostra de sa�da
        function xk = update(obj, yk)
            % Atualiza o K
            obj.K = obj.pk_minus * obj.C' / (obj.C * obj.pk_minus * obj.C' + obj.R);

            % atualiza x a posteriori
            obj.xk_minus = obj.xk_minus + obj.K * (yk - obj.C * obj.xk_minus);
            xk = obj.xk_minus;

            % atualiza p a posteriori
            obj.pk_minus = obj.pk_minus - obj.K * obj.C * obj.pk_minus;

            % Atualiza x e k anteriori, para calcular a proxima predi��o
            obj.xk_1_minus = obj.xk_minus;
            obj.pk_1_minus = obj.pk_minus;
        end
    end
    
end

