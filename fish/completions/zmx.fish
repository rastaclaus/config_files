# zmx ставится только на headless-хосты (hosts/work/packages-aur.txt) —
# без проверки fish ругался бы при старте на машинах без него.
type -q zmx; and zmx completions fish | source
