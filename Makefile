# include PATHs
IDIR		:= /usr/include/lua5.3
# destination PATHs
TRIPLET		:= $(shell gcc -dumpmachine)
LDIR		:= /usr/lib/$(TRIPLET)/lua/5.3
SYSTEMDIR	:= /lib/systemd/system

# Shared Library
NAME		:= ats
MAJOR		:= 0
MINOR		:= 2
VERSION	:= $(MAJOR).$(MINOR)

DEPS		:= lua5.3

CC		:= gcc # Compiller
CFLAGS		:= -c -fPIC -Wall -Werror -O3 -g -I$(IDIR) # Compiler Flags
LDFLAGS	:= -shared -Wl,-soname,$(NAME).so.$(MAJOR) -l$(DEPS) # Linker Flags

# source code
SRCS		:= ats.c
SRCS_PATH	:= src/
SRCS		:= $(addprefix $(SRCS_PATH),$(SRCS))
OBJS		:= $(SRCS:.c=.o)

# systemd service
SERVICE_PATH	:= systemd

.PHONY: all
all   : $(NAME).so.$(VERSION)


$(OBJS): $(SRCS)
	$(CC) ${CFLAGS} -o $@ $<


$(NAME).so.$(VERSION): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $<


.PHONY:	install
install:
	@if [ -L "/var/run/systemd/units/invocation:ats.service" ];then	\
		systemctl stop ats;					\
	fi
	@install --preserve-timestamps --owner=root --group=root --mode=750 --target-directory=/usr/sbin $(SRCS_PATH)ats
	@install --preserve-timestamps --owner=root --group=root --mode=640 --target-directory=$(SYSTEMDIR) $(SERVICE_PATH)/ats.service
	@if [ ! -d $(LDIR) ];then													\
		mkdir -p $(LDIR);													\
	elif [ -L $(LDIR)/$(NAME).so ] || [ -f $(LDIR)/$(NAME).so.?.? ];then								\
		rm -f $(LDIR)/$(NAME).so*												\
	elif [ -L $(LDIR)/fanctl.so ] || [ -L $(LDIR)/sleep.so  || [ -f $(LDIR)/fanctl.so.?.? ] || [ -f $(LDIR)/sleep.so.?.? ];then	\
		systemctl stop fanctl 1> /dev/null 2>&1											\
		journalctl -u fanctl --rotate 1> /dev/null 2>&1										\
		sync && sleep 1														\
		journalctl -u fanctl --vacuum-time=1s 	1> /dev/null 2>&1								\
		find /{lib/systemd/system,usr/{sbin,lib/$(gcc -dumpmachine)/lua/5.3,sbin}} \( -name fanctl -o -name sleep.so\* -o -name fanctl.service \) -exec rm -v {} \;	\
	fi
	@install --preserve-timestamps --owner=root --group=root --mode=640 --target-directory=$(LDIR) $(NAME).so.$(VERSION)
	@ln -s $(LDIR)/$(NAME).so.$(VERSION) $(LDIR)/$(NAME).so
	@systemctl enable ats
	@systemctl start ats
	@sleep 1
	systemctl status ats


.PHONY:	clean
clean:
	rm $(OBJS)
	rm $(NAME).so.$(VERSION)

.PHONY: purge
purge:
	cd / && rm -rf ${OLDPWD}/ats
