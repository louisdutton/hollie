*** Settings ***
Resource         game.resource
Test Teardown    Save Journey Evidence

*** Variables ***
&{title_audio_music}    path=audio/A-Feather-Falls-Ian-Aisling-stream-preview.mp3    playing=${True}
&{title_audio_ambience}    path=audio/Birdsong-River-Flow-Early-Morning-Woodland-stream-preview.mp3    playing=${True}
&{title_audio}    Music=${title_audio_music}    Ambience=${title_audio_ambience}
&{demo_audio_music}    path=audio/A-Legend-Ian-Aisling-stream-preview.mp3    playing=${True}
&{demo_audio_ambience}    path=audio/Wind-Ambience-Distant-City-stream-preview.mp3    playing=${True}
&{demo_audio}    Music=${demo_audio_music}    Ambience=${demo_audio_ambience}
&{inside_audio_music}    path=audio/music/ambient.ogg    playing=${True}
&{inside_audio}    Music=${inside_audio_music}

*** Test Cases ***
Title birdsong and demo wind layered playback, pause and room transitions
    ${title}=    Observe Game
    Should Be Equal    ${title}[audio]    ${title_audio}
    ${demo}=    Reset Game
    Should Be Equal    ${demo}[audio]    ${demo_audio}
    ${paused}=    Advance Ticks    1    P
    Should Be Equal    ${paused}[audio]    ${demo_audio}
    Advance Ticks    1
    Advance Ticks    1    ENTER
    Advance Ticks    8    W    D
    ${inside}=    Advance Ticks    45
    Should Be Equal    ${inside}[audio]    ${inside_audio}
    Should Be Equal    ${inside}[room]    small_room
    Advance Ticks    1
    Advance Ticks    8    A    S
    ${returned}=    Advance Ticks    45
    Should Be Equal    ${returned}[audio]    ${demo_audio}
    Should Be Equal    ${returned}[room]    demo
