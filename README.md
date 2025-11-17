# simufy
Patch ios applications to make them runnable on the simulator.

## Usage
`./convert.sh Example.app`

## Build
`clang -framework Foundation -o simufy main.m`

## References
- dyld source code for analyzing platforms
    - https://github.com/apple-oss-distributions/dyld/blob/637911768f664e38e7e50b4fbf17e303e14fdc01/mach_o/Header.cpp#L337
    - https://github.com/apple-oss-distributions/dyld/blob/637911768f664e38e7e50b4fbf17e303e14fdc01/mach_o/Header.cpp#L1113
- useful paths (Xcode 26.0.1)
    - app logs: ~/Library/Logs/DiagnosticReports
    - sim runtime: /Library/Developer/CoreSimulator/Volumes/
    - sim data: ~/Library/Developer/CoreSimulator/Devices/<UUID>/