*** Settings ***
Library          robot_game.Hollie    ${CONTROL_SOURCE}    ${ARTIFACT_DIR}
Test Teardown    Save Journey Evidence

*** Test Cases ***
Movement Freezes Between Commands And Replays Exactly
    ${initial}=    Reset Game    room=demo    players=${1}    seed=${42}    capture=initial.png
    Sleep    0.5s
    ${idle}=    Observe Game
    States Should Match    ${initial}    ${idle}
    ${moved}=    Advance Ticks    30    S    capture=moved.png
    Sleep    0.5s
    ${held_idle}=    Observe Game
    States Should Match    ${moved}    ${held_idle}

    Advance Ticks    0    expected_error=frames must be between 1 and 600
    Reset Should Fail    does_not_exist    unknown room
    ${after_errors}=    Observe Game
    States Should Match    ${moved}    ${after_errors}

    ${reset}=    Reset Game    room=demo    players=${1}    seed=${42}
    States Should Match    ${initial}    ${reset}
    ${replayed}=    Advance Ticks    30    S    capture=replayed.png
    States Should Match    ${moved}    ${replayed}
    Player Should Have Moved    ${initial}    ${moved}
    Frames Between Should Be    ${initial}    ${moved}    30
    Images Should Match    moved.png    replayed.png
