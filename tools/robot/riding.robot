*** Settings ***
Library          robot_game.Hollie    ${CONTROL_SOURCE}    ${ARTIFACT_DIR}
Resource         riding.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Riding Animation And Dismount Replay Exactly
    ${initial}=    Reset Game
    Approach Horse And Mount
    ${mounted}    ${turning}=    Ride And Turn    mounted.png    riding.png    turning.png
    Mounted Actor Should Be    ${mounted}    8
    ${dismounted}    ${settled}=    Jump And Dismount    jump.png    airborne.png    landed.png    dismount.png
    Mounted Actor Should Be    ${dismounted}    0
    Sleep    0.5s
    ${idle}=    Observe Game
    States Should Match    ${settled}    ${idle}

    ${reset}=    Reset Game
    States Should Match    ${initial}    ${reset}
    Approach Horse And Mount
    ${mounted}    ${replayed}=    Ride And Turn    turning_capture=replayed.png
    States Should Match    ${turning}    ${replayed}
    Jump And Dismount
    Images Should Match    turning.png    replayed.png
