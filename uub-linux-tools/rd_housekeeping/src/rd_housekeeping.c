/*
 * Auger RD housekeeping dump tool (using spidev driver)
 *
 * Copyright (c) 2019  Radboud Radio Lab
 * Author: Sjoerd T. Timmer (s.timmer@astro.ru.nl)
 *
 * Cross-compile with cross-gcc -I/path/to/cross-kernel/include
 */

#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <time.h>
#include <stdio.h>
#include <stdbool.h>
#include <sys/ioctl.h>
#include <linux/ioctl.h>
#include <sys/stat.h>
#include <linux/types.h>
#include <linux/spi/spidev.h>

static void pabort(const char *s)
{
	perror(s);
	abort();
}

static const char *device = "/dev/spidev32765.0";
static uint32_t mode = SPI_CPHA | SPI_CPOL;
static uint8_t bits = 8;
static uint32_t speed = 500000;
static uint16_t delay = 0;
static bool verbose = false;
static bool loop = false;
static uint32_t interval;
static bool do_sw_trigger = false;
static bool do_fw_version = false;
static uint16_t trigger_offset = 0;

static void transfer(int fd, uint8_t const *tx, uint8_t const *rx, size_t len)
{
	int ret;
	int i;
	struct spi_ioc_transfer tr = {
		.tx_buf = (unsigned long)tx,
		.rx_buf = (unsigned long)rx,
		.len = len,
		.delay_usecs = delay,
		.speed_hz = speed,
		.bits_per_word = bits,
	};

	if (verbose && tx) {
		printf("raw out binary:");
		for(i = 0; i < len; ++i) {
			printf(" %02X", tx[i]);
		}
		printf("\n");
	}

	ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1)
		pabort("can't send spi message");

	if (verbose && rx) {
		printf("raw in binary:");
		for(i=0; i<len; ++i) {
			printf(" %02X", rx[i]);
		}
		printf("\n");
	}
}

static void print_usage(const char *prog)
{
	printf("Usage: %s [-Dsv]\n", prog);
	puts("  -D --device      device to use (default /dev/spidev32765.0)\n"
	     "  -s --speed       max speed (in Hz, default 500000)\n"
	     "  -v --verbose     verbose (show tx and rx buffers)\n"
         "  -V --version     print FW version\n"
         "  -o --startoffset set the offset of the trigger point from the start of the capture window\n"
		 "  -l --loop        repeat measurement in infinite loop\n"
		 "  -i --interval    interval for loop(in milliseconds)\n"
		 "  -t --trigger     inject a firmware trigger to force a conversion before each readout.\n");
	exit(1);
}

static void parse_opts(int argc, char *argv[])
{
	while (1) {
		static const struct option lopts[] = {
			{ "device",      1, 0, 'D' },
			{ "speed",       1, 0, 's' },
			{ "verbose",     0, 0, 'v' },
            { "version",     0, 0, 'V' },
			{ "loop",        0, 0, 'l' },
            { "startoffset", 1, 0, 'o' },
			{ "interval",    0, 0, 'i' },
			{ "trigger" ,    0, 0, 't' },
			{ NULL,          0, 0, 0   },
		};
		int c;

		c = getopt_long(argc, argv, "D:s:vVlo:i:t", lopts, NULL);

		if (c == -1)
			break;

		switch (c) {
		case 'D':
			device = optarg;
			break;
		case 's':
			speed = atoi(optarg);
			break;
		case 'v':
			verbose = 1;
			break;
        case 'V':
            do_fw_version = true;
            break;
		case 'l':
			loop = 1;
			break;
        case 'o':
            trigger_offset = atoi(optarg);
            break;
		case 'i':
			interval = atoi(optarg);
			break;
		case 't':
			do_sw_trigger = 1;
			break;
		default:
			print_usage(argv[0]);
			break;
		}
	}
}

static void setup_port(int fd)
{
	/*
	 * spi mode
	 */
	int ret = ioctl(fd, SPI_IOC_WR_MODE32, &mode);
	if (ret == -1)
		pabort("can't set spi mode");

	ret = ioctl(fd, SPI_IOC_RD_MODE32, &mode);
	if (ret == -1)
		pabort("can't get spi mode");

	/*
	 * bits per word
	 */
	ret = ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
	if (ret == -1)
		pabort("can't set bits per word");

	ret = ioctl(fd, SPI_IOC_RD_BITS_PER_WORD, &bits);
	if (ret == -1)
		pabort("can't get bits per word");

	/*
	 * max speed hz
	 */
	ret = ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed);
	if (ret == -1)
		pabort("can't set max speed hz");

	ret = ioctl(fd, SPI_IOC_RD_MAX_SPEED_HZ, &speed);
	if (ret == -1)
		pabort("can't get max speed hz");

	if (verbose) {
		printf("spi mode: 0x%x\n", mode);
		printf("bits per word: %d\n", bits);
		printf("max speed: %d Hz (%d KHz)\n", speed, speed/1000);
	}
}

static void set_trigger_offset(int fd, uint16_t off)
{
	printf("Setting trigger offset: %d\n", off);
	if (off >= 2048)
    {
        printf("Offset out of range (1-2047): %d\n", off);
        exit(-1);
    }
    uint8_t hword = off >> 8;
    uint8_t lword = off & 0xff;

        uint8_t tx[] = {
        0x08 /*subsystem*/,
        hword,
        lword
    };
    transfer(fd, tx, NULL, sizeof(tx));

    printf("trigger offset set done\n");
}

static void sw_trigger(int fd)
{
	uint8_t tx[] = {0x06/*subsystem*/};
	uint8_t* rx = malloc(sizeof(tx));
	transfer(fd, tx, rx, sizeof(tx));
	free(rx);
}

static void print_fw_version(int fd)
{
    uint8_t buf[] = {0x07/*subsystem*/, 0x00/*space for response*/};
    transfer(fd, buf, buf, sizeof(buf));
    printf("Firmware version on board: 0x%02X\n", buf[1]);
}

static double * get_ads1015_data(int fd)
{
	uint8_t tx[] = {
        0x04/*subsystem*/,
        0x00/*bits 11:4 of channel 0*/,
        0x01/*bits 3:0  of channel 0*/,
        0x02/*bits 11:4 of channel 1*/,
        0x03/*bits 3:0  of channel 1*/,
        0x04/*bits 11:4 of channel 2*/,
        0x05/*bits 3:0  of channel 2*/,
        0x06/*bits 11:4 of channel 3*/,
        0x07/*bits 3:0  of channel 3*/,
        0x00/*padding for the result*/};
	uint8_t* rx = malloc(sizeof(tx));
	transfer(fd, tx, rx, sizeof(tx));

    // reserve space for result:
    double * res = malloc(4 * sizeof(double));
    
	// reapeat for 4 channels:
    int ch;
    for (ch = 0; ch < 4; ch++)
    {
        // decode the bytes to an int:
        uint16_t val = (rx[2 + 2 * ch] << 4) + (rx[3 + 2 * ch] >> 4);
        if (verbose)
        {
            printf("channel %d: integer value: %u\n", ch, val);
        }

        // convert to voltage
        res[ch] = 0.001 * val; // assuming 2.048V FSR, LSB=1mV
        if (verbose)
        {
            printf("Voltage reading: %0.3fV\n", res[ch]);
        }
    }
	free(rx);
	return res;
}

static double get_si7060_data(int fd)
{
	uint8_t tx[] = {
			0x05/*subsystem*/,
			0x00/*data low word*/,
			0x01/*data high word*/,
			0x00/*padding for the result*/ };
	uint8_t* rx = malloc(sizeof(tx));
	transfer(fd, tx, rx, sizeof(tx));

	// decode the bytes to an int:
	uint16_t val = ((rx[1] & 0b01111111)<<8) + rx[0];
	if (verbose)
	{
		printf("unsigned value: %u\n", val);
	}

	// convert to voltage
	double T = 55.0 + 1.0*(val-16384)/160.0;
	if (verbose)
	{
		printf("Temperature reading: %0.3f C\n", T);
	}

	free(rx);
	return T;
}

int main(int argc, char *argv[])
{
	parse_opts(argc, argv);

	int fd = open(device, O_RDWR);
	if (fd < 0)
		pabort("can't open device");

	setup_port(fd);

    if (do_fw_version)
        print_fw_version(fd);
    
    if (trigger_offset > 0)
    {
    	set_trigger_offset(fd, trigger_offset);
    }

	double T, *V;
loop:
	if (do_sw_trigger)
		sw_trigger(fd);
	V = get_ads1015_data(fd);
	T = get_si7060_data(fd);
	printf("Temperature: %0.3f\n", T);
	int ch;
	for (ch=0; ch<4; ch++)
	{
		printf("Channel %d voltage: %0.3f\n", ch, V[ch]);
	}
	free(V);

	if (loop)
	{
		usleep(interval*1000);
		goto loop;
	}

	close(fd);

	return 0;
}
