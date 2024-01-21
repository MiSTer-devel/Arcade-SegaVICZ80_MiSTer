#export OPTIMIZE="-O3 --x-assign fast --x-initial fast --noassert"
export OPTIMIZE="--x-assign fast --x-initial fast --noassert"
#export WARNINGS="-Wno-WIDTHCONCAT -Wno-WIDTH"
export WARNINGS="-Wno-fatal"


set -e
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
verilator \
-cc --compiler msvc +define+SIMULATION=1 $WARNINGS $OPTIMIZE \
--top-module emu sim.v \
-I../rtl \
-I../rtl/tv80 \
-I../rtl/jt49 \
-I../rtl/tv48 \
-I../rtl/sound
else
	echo "not running on windows"
fi
