.PHONY: update-lib

update-lib:
	git submodule update --remote Vendor/libxlsxwriter
	@echo "libxlsxwriter updated to $$(cd Vendor/libxlsxwriter && git describe --tags 2>/dev/null || git rev-parse --short HEAD)"
