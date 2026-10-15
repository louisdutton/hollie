*** Keywords ***
# These calibrated analog corrections preserve the recorded approach trajectories.
Approach Horse And Mount
    Move Stick For Ticks    20    0.18208926018230742    0.9832820049844601
    Move Stick For Ticks    20    0.23249326674782425    0.9725980058158279
    Move Stick For Ticks    20    0.30301130803444143    0.9529869606680128
    Move Stick For Ticks    20    0.37738556927457045    0.9260562251306926
    Move Stick For Ticks    20    0.4551681480000427    0.8904055014689717
    Move Stick For Ticks    20    0.5356304623927123    0.8444524899347324
    Move Stick For Ticks    20    0.6306703530275175    0.7760508397084217
    Move Stick For Ticks    12    0.8510623972104095    0.5250645637009519
    Move Stick For Ticks    4    0.9828640627350969    0.18433185884121994
    Advance Ticks    1    J

Approach Crate And Pick Up
    Advance Ticks    210    W    A
    Move Stick For Ticks    20    0.519835841299341    -0.8542661752057178
    Move Stick For Ticks    20    0.5393962488509302    -0.8420520688921471
    Move Stick For Ticks    20    0.5393958904944826    -0.842052298445687
    Move Stick For Ticks    20    0.5393954256760297    -0.8420525961956147
    Move Stick For Ticks    20    0.539394798676725    -0.8420529978335658
    Move Stick For Ticks    20    0.5393939066791039    -0.8420535692207795
    Move Stick For Ticks    20    0.5393925366677355    -0.8420544468068235
    Move Stick For Ticks    20    0.5393901637566002    -0.842055966811368
    Move Stick For Ticks    20    0.5393959202079566    -0.8420522794120395
    Move Stick For Ticks    4    0.5393916865237812    -0.8420549913806288
    Advance Ticks    1    J

Approach Bison And Mount
    Advance Ticks    90    S    D
    Move Stick For Ticks    6    0.9956848363229206    -0.09279928187544782
    Move Stick For Ticks    4    0.9820934215753893    -0.18839456281523817
    Advance Ticks    1    J
