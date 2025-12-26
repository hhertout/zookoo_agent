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

format:
	@echo "Formatting code..."
	@zig fmt .

check-format:
	@echo "Checking code formatting..."
	@zig fmt --check .