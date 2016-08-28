.PHONY: itests tests install all

PYENV ?= . .pyenv/bin/activate &&
TESTS ?= tests
PREFIX ?= /usr/local
SHELL ?= zsh

itests:
	${MAKE} tests CRAM_OPTS=-i

tests:
	${PYENV} ZDOTDIR="${PWD}/tests" cram ${CRAM_OPTS} --shell=${SHELL} ${TESTS}

stats:
	cp ${PWD}/tests/.zshrc ${HOME}/.zshrc
	for i in $$(seq 1 10); do /usr/bin/time -f "#$$i \t%es real \t%Us user \t%Ss system \t%x status" ${SHELL} -ic exit; done

install:
	mkdir -p ${PREFIX}/share && cp ./antigen.zsh ${PREFIX}/share/antigen.zsh

clean:
	rm -f ${PREFIX}/share/antigen.zsh

all: clean install
