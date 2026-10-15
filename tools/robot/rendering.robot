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
    IF    $SESSION['backend'] == 'xvfb'
        Capture Private Display    display.png
        Image Dimensions Should Be    display.png    ${SESSION}[width]    ${SESSION}[height]
        FOR    ${side}    IN    West    East
            ${brightness}=    Image Edge Brightness    display.png    ${side}
            Should Be True    $brightness >= 0.01
        END
    END
