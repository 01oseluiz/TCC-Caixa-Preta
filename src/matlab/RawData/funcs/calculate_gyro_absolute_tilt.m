function ret = calculate_gyro_absolute_tilt(relative_tilt)
    % Calcula a matriz de Rota��o (Z,Y,X) que move o corpo da Posi��o inicial para a Posi��o atual
    Rot = ang2rotZYX(relative_tilt(1), relative_tilt(2), relative_tilt(3));

    %% Extrai Yaw, Pitch e Roll absolutos(em rela��o a Posi��o inicial do corpo) p/ a nova amostra usando a atual matriz de Rota��o (Z,Y,X)
    % Ref do calculo: https://www.youtube.com/watch?v=wg9bI8-Qx2Q
    newRoll = atan2(Rot(3,2), Rot(3,3)) * 180/pi;
    newYaw = atan2(Rot(2,1), Rot(1,1)) * 180/pi;
    if cosd(newYaw) == 0
        newPitch = atan2(-Rot(3,1), Rot(2,1)/sind(newYaw)) * 180/pi;
    else
        newPitch = atan2(-Rot(3,1), Rot(1,1)/cosd(newYaw)) * 180/pi;
    end

    ret = [newRoll, newPitch, newYaw];
end