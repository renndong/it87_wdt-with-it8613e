DRIVER := it87_wdt
KRELEASE ?= $(shell uname -r)
obj-m := $(patsubst %,%.o,$(DRIVER))
obj-ko := $(patsubst %,%.ko,$(DRIVER))
KMODULES := /lib/modules/$(KRELEASE)
KBUILD := $(KMODULES)/build

MAKEFLAGS += --no-print-directory

ifneq (,$(wildcard .git/*))
DRIVER_VERSION := $(shell git rev-parse --short HEAD)
else
DRIVER_VERSION := $(shell grep -s "PACKAGE_VERSION" $(CURDIR)/dkms.conf | sed -r 's/.*"(.+)"/\1/')
endif

ifneq (,$(wildcard /boot/System.map-$(KRELEASE)))
SYSTEM_MAP	:= /boot/System.map-$(KRELEASE)
else
SYSTEM_MAP	:= /proc/kallsyms
endif

DKMS_ROOT_PATH := /usr/src/$(DRIVER)-$(DRIVER_VERSION)
MODDESTDIR := $(KMODULES)/kernel/drivers/watchdog
MODLOADDIR := /usr/lib/modules-load.d
EXTRA_CFLAGS += -DDRIVER_VERSION='\"$(DRIVER_VERSION)\"'

.PHONY: modules install clean dkms dkms_clean

modules:
	$(MAKE) EXTRA_CFLAGS="$(EXTRA_CFLAGS)" -C $(KBUILD) M=$(CURDIR) $@

install: modules
	install -m 644 -D $(DRIVER).ko $(MODDESTDIR)/$(DRIVER).ko
	install -m 644 -D $(DRIVER).conf $(MODLOADDIR)/$(DRIVER).conf
	depmod -a -F $(SYSTEM_MAP) $(KRELEASE)

clean:
	$(MAKE) -C $(KBUILD) M=$(CURDIR) $@

dkms:
	sed -i -e '/^PACKAGE_VERSION/ s/\".*\"/\"$(DRIVER_VERSION)\"/' dkms.conf
	mkdir $(DKMS_ROOT_PATH)
	cp $(CURDIR)/dkms.conf $(CURDIR)/it87_wdt.c $(CURDIR)/Makefile \
		$(DKMS_ROOT_PATH)
	dkms add -m $(DRIVER) -v $(DRIVER_VERSION)
	dkms build -m $(DRIVER) -v $(DRIVER_VERSION)
	dkms install --force -m $(DRIVER) -v $(DRIVER_VERSION)
	modprobe $(DRIVER)

dkms_clean:
	dkms remove -m $(DRIVER) -v $(DRIVER_VERSION) --all
	rm -rf $(DKMS_ROOT_PATH)
	[ -z "$(shell lsmod | grep $(DRIVER))" ] || rmmod $(DRIVER)