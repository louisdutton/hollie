*** Settings ***
Library    robot_game.Hollie

*** Variables ***
${GAME_EXECUTABLE}     %{CARGO_TARGET_DIR}/debug/hollie
${GAME_BACKEND}        offscreen
${GAME_GPU}            ${None}
${GAME_DISPLAY_SIZE}   1280x720
${GAME_RENDER_SIZE}    640x360
${GAME_DISPLAY_SCALE}    ${None}

*** Keywords ***
Start Journey
    ${session}=    Start Private Game    ${GAME_EXECUTABLE}    ${GAME_BACKEND}    ${GAME_GPU}
    ...    ${GAME_DISPLAY_SIZE}    ${GAME_RENDER_SIZE}    ${GAME_DISPLAY_SCALE}
    Set Test Variable    ${SESSION}    ${session}
