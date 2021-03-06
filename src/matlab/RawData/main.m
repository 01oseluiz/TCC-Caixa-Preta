% Ler da porta serial
% Ainda precisa melhorar
% BUGS:
% - file_simulated_freq ainda n�o funciona muito bem

% Importa tudo que esta na mesma raiz que a main.m, incluindo pastas e subpastas
addpath(genpath('.'))

close all;                          % close all figures
clear;                              % clear all variables
clc;                                % clear the command terminal

%% 1 - Obtem configura��es est�ticas
cnf = Configs();

%% 2 - Abre porta serial / arquivo
if cnf.read_from_serial
    reader = ReaderSerial(cnf.serial_COM, cnf.serial_baudrate);
else
    reader = ReaderFile(cnf.file_full_path);
end

%% 3 - Atualiza as configura��es com metadados da caixa preta
cnf.setDynamicConfigs(reader.metadatas);

%% 4 - Inst�ncia todo o conjunto de gr�ficos
charts = Charts(cnf);

%% 5 - Obtem a configura��o do layout
cnf.setLayout(charts);

%% 6 - Define uma janela p/ plot
plot_1 = Render(cnf.freq_render, cnf.layout);

%% Obtem os dados e plota em tempo real
% NOTA: Se o buffer do serial encher (> 512 bytes) o programa pode explodir ou apresentar erros, caso isso ocorra
% abaixe a taxa de renderiza��o do gr�fico. Para verificar se erros ocorreram, compare a quantidade de amostras enviadas com a quantidade lida
time_calc_data = 0;
count=0;                                 % conta quantas amostras foram lidas
while true
    
    %% L� uma amostra de cada da porta serial/arquivo
    data = reader.read_sample();
    
    % Se � o fim do arquivo ou deu algum erro finaliza
    if isempty(data)
        break;
    end
    
    count=count+1;
    
    t1 = tic;
    data = str2int16(data);

    % Chama cada gr�fico na tela para realizar seus calculos
    % atualizando os dados a partir dos dados de entrada
    for i = 1:length(plot_1.plots)
        plot_1.plots(i).calculate(data, count);
    end
    
    time_calc_data = time_calc_data + toc(t1);

    %% Tenta redesenhar os graficos na tela com os novos dados, se deu o tempo da frequencia
    % Este redesenho frequente da tela ainda n�o � algo bem modelado, podendo causar lentid�es e travamento
    % desabilite o 'plot_in_real_time' nas configura��es para melhor performance
    if cnf.plot_in_real_time
        plot_1.try_render();
    end
end

%% Renderiza pela ultima vez, independente de ter dado o tempo da frequencia
plot_1.force_render();

reader.delete();
plot_1.delete();

%% Calcula m�dia dos tempos
fprintf('Tempo m�dio de calculo: %fs\n', time_calc_data / count);

%% Aqui acaba o script
fprintf(1,'Recebidos %d amostras\n\n',count);
return;