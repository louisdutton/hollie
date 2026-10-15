*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Title and gameplay fill the requested render extent
    Observe Game    capture=title.png
    Reset Game    capture=gameplay.png
    Image Dimensions Should Be    title.png    ${SESSION}[width]    ${SESSION}[height]
    Image Dimensions Should Be    gameplay.png    ${SESSION}[width]    ${SESSION}[height]
