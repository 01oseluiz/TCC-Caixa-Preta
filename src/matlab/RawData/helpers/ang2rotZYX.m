function ret = ang2rotZYX( Z, Y, X )
% euler angles(in deg) to rotation matrix ZYX
%  
    temp_Rx = [...
        [1,     0,        0       ];...
        [0,     cosd(X),  -sind(X)];...
        [0,     sind(X),  cosd(X) ]
    ];
    temp_Ry = [...
        [cosd(Y),         0,       sind(Y)];...
        [0,               1,       0      ];...
        [-sind(Y),        0,       cosd(Y)]
    ];
    temp_Rz = [...
        [cosd(Z),         -sind(Z),       0];...
        [sind(Z),         cosd(Z),        0];...
        [0,               0,              1]
    ];

    ret = temp_Rz * temp_Ry * temp_Rx;
end

