This thing can control any fan connected to your motherboard based on your NVIDIA GPU temperature, and a custom user-defined fan-curve. Includes a basic configurator

What it does:
- Reads the csv config file (use configurator if you don't have that file)
- Reads the GPU temperature from nvidia-smi
- Based on that, reads first column (temperature) and the second column (PWM value) of our config file
- Does math (if temp <= second column, set fan speed)
- Sets fan to (manual) software control
- Echoes PWM value to hwmon2/pwm2 (for now)
