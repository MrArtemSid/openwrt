#
# Copyright (C) 2026 OpenWrt.org
#

include $(TOPDIR)/rules.mk

PKG_NAME:=santoni-support
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/package.mk

define Package/santoni-support
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Xiaomi Redmi 4X (santoni) Bring-up and Hardware Support
  DEPENDS:=@TARGET_armsr_armv8
endef

define Package/santoni-support/description
  Init scripts and support services for Xiaomi Redmi 4X (santoni / MSM8937)
  including WCN36xx Wi-Fi, Hexagon MPSS modem, and RMTFS NV storage.
endef

define Build/Compile
endef

define Package/santoni-support/install
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) ./files/santoni_setup.sh $(1)/usr/bin/santoni_setup.sh
	$(INSTALL_BIN) ./files/rmtfs $(1)/usr/bin/rmtfs
	$(INSTALL_BIN) ./files/qrtr-lookup $(1)/usr/bin/qrtr-lookup
	$(INSTALL_BIN) ./files/santoni_init $(1)/etc/init.d/santoni
	$(INSTALL_DATA) ./files/hostapd.conf $(1)/etc/hostapd.conf
endef

define Package/santoni-support/postinst
#!/bin/sh
[ -n "$$IPKG_INSTROOT" ] || {
	/etc/init.d/santoni enable
}
exit 0
endef

$(eval $(call BuildPackage,santoni-support))
