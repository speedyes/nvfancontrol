# Description
This thing can control any fan connected to your motherboard based on your NVIDIA GPU temperature, and a custom user-defined fan-curve. Includes an configurator

# What it does:
- Reads the CSV config file (use configurator if you don't have that file)
- Reads the GPU temperature from nvidia-smi
- Based on that, reads first column (temperature) and the second column (PWM value) of our config file
- Does some math
- Sets fan to (manual) software control
- Echoes PWM value to user-specified PWM device

# What the configurator can do:
- Input can be both percentage and PWM value (user selectable)
- Can generate a graph with gnuplot based on csv file saved at the end
- Check if the config already exists
- Save necesarry files automatically at /home/user/.config/nvfanconf/
- Can spin up a fan to a desired value to test if speed is acceptable (sudo required)
- Works both with sudo and without

# First use:
- Make sure you have necesarry driver installed for your super-io chip (run 'sensors-detect' and 'sensors', and check if you have 'fan x' followed by RPM value)
- Make sure you know where in the filesystem resides your PWM fan (pwmconfig can detect it, ex. /sys/class/hwmon/hwmon1/pwm1)
- Run the configurator first, then open the main script and replace 'none' with things explained in the comments

# Usage:
- Just run the script with sudo
- Configurator is now run with '-c' switch. It can be run both with sudo and without

# Tips:
- I recommend enabling 'nvfancontrol.sh' as a service, no tutorial (from me) for now
- If you want to make your graph a bit more detailed, then you can edit config file directly with any editor. First column is desired temperature and second is fan speed in PWM (ex. 40,110)

# TODO:
- [ ] Make the configurator reserve lines for itself and clear them when screen update occurs
- [x] Merge configurator and fancontrol script into one
- [ ] Add last set temperature to configurator output
- [ ] Make some changes to the script for smooth fan changes
- [ ] Make the configurator more user-friendly (options selectable by arrow keys etc.)
- [ ] Maybe a basic GUI? I'm not sure about that one but it's what I would like to make in the future 
