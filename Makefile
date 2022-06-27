.PHONY: test
.SILENT: test

test: tests/*.ps1
	for file in $^ ; do \
		echo "Running " $${file} ; \
		pwsh $${file} ; \
	done
