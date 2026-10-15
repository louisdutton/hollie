*** Settings ***
Resource         game.resource
Resource         routes.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Mounted motion, jump, dismount momentum and seeded replay
    ${initial}=    Reset Game
    Approach Horse And Mount
    ${mounted}=    Advance Ticks    30    capture=mounted.png
    Should Be Equal    ${mounted}[players][0][mounted]    ${8}
    ${riding}=    Advance Ticks    60    S    D    capture=riding.png
    ${turning}=    Advance Ticks    45    S    A    capture=turning.png
    ${jump}=    Advance Ticks    1    H    capture=jump.png
    ${airborne}=    Advance Ticks    18    capture=airborne.png
    ${landed}=    Advance Ticks    120    capture=landed.png
    ${dismount}=    Advance Ticks    1    J    capture=dismount.png
    Should Be Equal    ${dismount}[players][0][mounted]    ${0}
    ${settled}=    Advance Ticks    80
    Sleep    0.5s
    ${idle}=    Observe Game
    Should Be Equal    ${settled}    ${idle}
    ${reset}=    Reset Game
    Should Be Equal    ${initial}    ${reset}
    Approach Horse And Mount
    Advance Ticks    30
    Advance Ticks    60    S    D
    ${replayed}=    Advance Ticks    45    S    A    capture=replayed.png
    Should Be Equal    ${turning}    ${replayed}
    Images Should Match    turning.png    replayed.png
    Advance Ticks    1    H
    Advance Ticks    18
    Advance Ticks    120
    Advance Ticks    1    J
    Advance Ticks    80

    Reset Game
    Approach Horse And Mount
    Advance Ticks    30
    ${standing_mounted}=    Observe Game    capture=standing-mounted.png
    ${standing_release}=    Advance Ticks    1    J    capture=standing-release.png
    Should Be True    abs($standing_release['players'][0]['body']['position']['x'] - $standing_mounted['players'][0]['riding_anchor']['x'] - 0) <= 4
    Should Be True    abs($standing_release['players'][0]['body']['position']['y'] - $standing_mounted['players'][0]['riding_anchor']['z'] - 0) <= 4
    Should Be True    abs($standing_release['players'][0]['body']['height'] - $standing_mounted['players'][0]['riding_anchor']['y'] - 0) <= 7
    Should Be Equal    ${standing_release}[players][0][mounted]    ${0}
    Should Be True    200 <= $standing_release['players'][0]['body']['vertical_velocity'] <= 500
    ${standing_flight}=    Advance Ticks    6    capture=standing-flight.png
    Should Be Equal    ${standing_flight}[players][0][dismount_air_control]    ${True}
    Should Be Equal    ${standing_release}[players][0][body][velocity]    ${standing_flight}[players][0][body][velocity]
    ${standing_settled}=    Advance Ticks    120
    Should Be Equal    ${standing_settled}[players][0][dismount_air_control]    ${False}
    Reset Game
    Approach Horse And Mount
    Advance Ticks    30
    Advance Ticks    60    S    D
    ${moving_mounted}=    Observe Game    capture=moving-mounted.png
    ${moving_release}=    Advance Ticks    1    J    capture=moving-release.png
    Should Be True    abs($moving_release['players'][0]['body']['position']['x'] - $moving_mounted['players'][0]['riding_anchor']['x'] - 0) <= 4
    Should Be True    abs($moving_release['players'][0]['body']['position']['y'] - $moving_mounted['players'][0]['riding_anchor']['z'] - 0) <= 4
    Should Be True    abs($moving_release['players'][0]['body']['height'] - $moving_mounted['players'][0]['riding_anchor']['y'] - 0) <= 7
    Should Be Equal    ${moving_release}[players][0][mounted]    ${0}
    Should Be True    200 <= $moving_release['players'][0]['body']['vertical_velocity'] <= 500
    ${moving_flight}=    Advance Ticks    6    capture=moving-flight.png
    Should Be Equal    ${moving_flight}[players][0][dismount_air_control]    ${True}
    Should Be Equal    ${moving_release}[players][0][body][velocity]    ${moving_flight}[players][0][body][velocity]
    ${moving_settled}=    Advance Ticks    120
    Should Be Equal    ${moving_settled}[players][0][dismount_air_control]    ${False}
    Reset Game
    Approach Horse And Mount
    Advance Ticks    30
    Advance Ticks    60    S    D
    Advance Ticks    4    H
    ${airborne_mounted}=    Observe Game    capture=airborne-mounted.png
    ${airborne_release}=    Advance Ticks    1    J    capture=airborne-release.png
    Should Be True    abs($airborne_release['players'][0]['body']['position']['x'] - $airborne_mounted['players'][0]['riding_anchor']['x'] - 0) <= 4
    Should Be True    abs($airborne_release['players'][0]['body']['position']['y'] - $airborne_mounted['players'][0]['riding_anchor']['z'] - 0) <= 4
    Should Be True    abs($airborne_release['players'][0]['body']['height'] - $airborne_mounted['players'][0]['riding_anchor']['y'] - 0) <= 7
    Should Be Equal    ${airborne_release}[players][0][mounted]    ${0}
    Should Be True    200 <= $airborne_release['players'][0]['body']['vertical_velocity'] <= 500
    ${airborne_flight}=    Advance Ticks    6    capture=airborne-flight.png
    Should Be Equal    ${airborne_flight}[players][0][dismount_air_control]    ${True}
    Should Be Equal    ${airborne_release}[players][0][body][velocity]    ${airborne_flight}[players][0][body][velocity]
    ${airborne_settled}=    Advance Ticks    120
    Should Be Equal    ${airborne_settled}[players][0][dismount_air_control]    ${False}
