*** Settings ***
Library    robot_game.Hollie

*** Variables ***
${GAME_EXECUTABLE}     %{CARGO_TARGET_DIR}/debug/hollie
${GAME_BACKEND}        offscreen
${GAME_DISPLAY_SIZE}   1280x720
${GAME_RENDER_SIZE}    640x360

*** Keywords ***
Start Journey
    ${session}=    Start Private Game    ${GAME_EXECUTABLE}    ${GAME_BACKEND}
    ...    ${GAME_DISPLAY_SIZE}    ${GAME_RENDER_SIZE}
    Set Test Variable    ${SESSION}    ${session}
