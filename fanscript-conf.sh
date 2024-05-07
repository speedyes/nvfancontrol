#!/bin/bash
# Function to write data to CSV
write_to_csv() {
    echo "$1,$2" >> fan_curve.csv
}

# Convert percentage to value from 0-255
convert_percent_to_pwm() {
    local percentage=$1
    # Calculate the value in the 0-255 range, rounding to the nearest whole number
    local pwm=$(( (percentage * 255 + 50) / 100 ))
    echo $pwm
}

# Generate a graph
graph() {
    if ! command -v gnuplot &> /dev/null; then
        echo "gnuplot not found! Program will not generate a fan curve graph."
        return
    else
        truncate -s 0 plot.gnuplot
        plot
    fi
}

plot() {
        echo $"set datafile separator ','" >> plot.gnuplot
        echo $'set title "Fan Curve"' >> plot.gnuplot
        echo $'set xlabel "Temperature"' >> plot.gnuplot
        echo $'set ylabel "Fan Speed (PWM)"' >> plot.gnuplot
        echo $"plot 'fan_curve.csv' using 1:2 with lines" >> plot.gnuplot
        echo "Opening gnuplot..."
        nohup gnuplot -p plot.gnuplot
}

# Clear the CSV file if it exists
if [ -f fan_curve.csv ]; then
    rm fan_curve.csv
fi

echo "Type at any moment 'exit' and changes will be saved to 'fan_curve.csv'."
echo "Tip: install gnuplot to display a nice fan curve graph at the end!"
echo ""
# Count steps
steps=0

# Ask user if they want to type in percentage of fan speed or raw value
echo "Speed% (0-100) or PWM (0-255)? (1-2)"
read calc
echo ""

# Loop to get user input
while true; do
    echo "Enter fan speed:"
    read fan_speed
    if [ "$fan_speed" == "exit" ]; then
        break
    fi

    echo "Enter temperature:"
    read temperature
    if [ "$temperature" == "exit" ]; then
        break
    else
        (( steps += 1 ))
        echo ""
        echo "steps = $steps"
        echo ""
    fi

    # Check if the input is a percentage
    if [[ $calc == 1 ]]; then
        # Convert the percentage to a value from 0-255
        fan_speed=$(convert_percent_to_pwm $fan_speed)
    fi

    # Validate fan speed is within 0-255
    if ! [[ $fan_speed =~ ^[0-9]+$ ]] || [ $fan_speed -lt 0 ] || [ $fan_speed -gt 255 ]; then
        echo "Invalid fan speed. Please enter a number between 0 and 255 or a percentage between 0 and 100."
        continue
    fi
    # Write the fan speed and temperature to the CSV file
    write_to_csv $temperature $fan_speed
done
echo "Configuration completed. Saved to fan_curve.csv."
graph
