*** Keywords ***
Approach Horse And Mount
    Move Stick For Ticks    20    0.18208926018230742    0.9832820049844601
    Move Stick For Ticks    20    0.23249326674782425    0.9725980058158279
    Move Stick For Ticks    20    0.30301130803444143    0.9529869606680128
    Move Stick For Ticks    20    0.37738556927457045    0.9260562251306926
    Move Stick For Ticks    20    0.4551681480000427     0.8904055014689717
    Move Stick For Ticks    20    0.5356304623927123     0.8444524899347324
    Move Stick For Ticks    20    0.6306703530275175     0.7760508397084217
    Move Stick For Ticks    12    0.8510623972104095     0.5250645637009519
    Move Stick For Ticks    4     0.9828640627350969     0.18433185884121994
    Advance Ticks    1    J

Ride And Turn
    [Arguments]    ${mounted_capture}=${EMPTY}    ${riding_capture}=${EMPTY}    ${turning_capture}=${EMPTY}
    ${mounted}=    Advance Ticks    30    capture=${mounted_capture}
    Advance Ticks    60    S    D    capture=${riding_capture}
    ${turning}=    Advance Ticks    45    S    A    capture=${turning_capture}
    RETURN    ${mounted}    ${turning}

Jump And Dismount
    [Arguments]    ${jump_capture}=${EMPTY}    ${airborne_capture}=${EMPTY}    ${landed_capture}=${EMPTY}    ${dismount_capture}=${EMPTY}
    Advance Ticks    1    H    capture=${jump_capture}
    Advance Ticks    18    capture=${airborne_capture}
    Advance Ticks    120    capture=${landed_capture}
    ${dismounted}=    Advance Ticks    1    J    capture=${dismount_capture}
    ${settled}=    Advance Ticks    80
    RETURN    ${dismounted}    ${settled}
