# nagios-plugin-check_tesla-gateway2

## check_tesla-gateway2

### EN

Nagios plugin to check on Tesla Gateway2 and, using this, Powerwall2

With the values and the status, performance values will be provided too. 
Using these performance values, it is easy to provide long-term statistics.


### Installation

1. Copy plugin to Plugin directory 

     These are usually placed in /usr/lib/nagios/plugins
   
2. Adjust permissions for plugin
     
	 Easiest way is to execute:
     chmod 755 /usr/lib/nagios/plugins/check_tesla-gateway2.pl

3. Check permissions on Nagios/Icinga cache directory
	 
	 The Cache directory for my configuration is /var/cache/icinga/
	 This might be different for your setuo, Pls check configuration file.
	 
	 chown -R nagios:www-data /var/cache/icinga
	 
	 chmod 750 /var/cache/icinga
	 chmod 660 /var/cache/icinga/*


### Usage

```
check_tesla-gateway2 -H|--Host host 
                     -E|--EMail [CustomerEMAIL] 
					 -P|--Password [password]
                     -e|--entity site|solar|load|battery
                     -s|--sensor
                     -c|--critical <thresholds> -w|--warning <thresholds>
                     [ -t|--timeout <timeout> ] 
                     [ --ignoressl ] 
                     [ -h|--help ]
```

#### Entity

	Valid entities are site|solar|load|battery

#### Sensor

	Valid values for sensor are:
	
		energy_exported
		energy_imported
		instant_power
		instant_reactive_power
		instant_apparent_power
		instant_average_voltage
		instant_average_current
		instant_total_current
		frequency
		i_a_current
		i_b_current
		i_c_current
	

### Example

```
./check_tesla-gateway2.pl -H 192.168.178.10 -E CustomerEMail -P yourpassword
                          -e Site -s instant_power --warning :5 --critical :10

```

Nagios Configuration can be found in subfolder EXAMPLE.

### Release notes

#### 1.0

- Inital version
