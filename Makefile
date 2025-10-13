# Project makefile

build:
	@echo "Building the project..."
	@zig build

run:
	@echo "Running the project..."
	@zig build run

test:
	@echo "Running tests..."
	@zig build test