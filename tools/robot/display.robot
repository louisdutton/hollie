*** Settings ***
Library          robot_game.Hollie    ${CONTROL_SOURCE}    ${ARTIFACT_DIR}
Test Teardown    Save Journey Evidence

*** Test Cases ***
Native 4K Survives A Windowed Fullscreen Round Trip
    Reset Game    capture=native-4k.png
    Image Dimensions Should Be    native-4k.png    3840    2160
    Advance Ticks    1    F3    capture=dimensions.png
    Image Dimensions Should Be    dimensions.png    3840    2160
    Open Visual Options
    Toggle Fullscreen And Capture    windowed.png
    Image Dimensions Should Be    windowed.png    1280    720
    Toggle Fullscreen And Capture    fullscreen-restored.png
    Image Dimensions Should Be    fullscreen-restored.png    3840    2160

*** Keywords ***
Open Visual Options
    Advance Ticks    1    P
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER

Toggle Fullscreen And Capture
    [Arguments]    ${capture}
    # Preserve the release tick before another ENTER edge.
    Advance Ticks    1
    Advance Ticks    1    ENTER    capture=${capture}
