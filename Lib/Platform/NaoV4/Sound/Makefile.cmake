CWD= $(shell pwd)
CTC= $(NaoqiCTC)

all: naoqi 

naoqi:
ifeq ($(CTC),)
	@echo Cross compilitation tool not specified. \
				Please download the ctc tool from \
				the aldebaran website and follow the \
				instructions to configure it for your system \
        && make -f Makefile.local
else
	rm -rf build
	mkdir build
	cd build && cmake -DCMAKE_TOOLCHAIN_FILE="$(CTC)/toolchain-atom.cmake" .. \
		&& make && cd $(CWD) && scp build/SoundComm.so build/play build/record nao@192.168.0.107:Player/

endif

clean:
ifeq ($(CTC),)
	make -f Makefile.local clean	
else
	rm -rf build
endif
