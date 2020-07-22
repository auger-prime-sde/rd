/*
 * rd_fft_readout.c
 *
 *  Created on: Jul 3, 2020
 *      Author: themba
 */



#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <time.h>
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
static uint32_t mode;
static uint8_t bits = 8;
static char *output_file;
static uint32_t speed = 500000;
static uint16_t delay = 0;
static int verbose;
static int num_bins  = 1024;
static int bin_width = 18;
static bool print_samples = false;
static bool write_decoded = false;
static bool set_averages = false;
static uint32_t averages = 2 * 1;

static void hex_dump(const void *src, size_t length, size_t line_size,
		     char *prefix)
{
	int i = 0;
	const unsigned char *address = src;
	const unsigned char *line = address;
	unsigned char c;

	printf("%s | ", prefix);
	while (length-- > 0) {
		printf("%02X ", *address++);
		if (!(++i % line_size) || (length == 0 && i % line_size)) {
			if (length == 0) {
				while (i++ % line_size)
					printf("__ ");
			}
			printf(" |");
			while (line < address) {
				c = *line++;
				printf("%c", (c < 32 || c > 126) ? '.' : c);
			}
			printf("|\n");
			if (length > 0)
				printf("%s | ", prefix);
		}
	}
}

static void transfer(int fd, uint8_t const *tx, uint8_t const *rx, size_t len)
{
	int ret;

	struct spi_ioc_transfer tr = {
		.tx_buf = (unsigned long)tx,
		.rx_buf = (unsigned long)rx,
		.len = len,
		.speed_hz = speed,
		.delay_usecs = delay,
		.bits_per_word = bits,
		.cs_change = 0,
		.tx_nbits = 8,
		.rx_nbits=8,
		.pad = 0
	};

	if (mode & SPI_TX_QUAD)
		tr.tx_nbits = 4;
	else if (mode & SPI_TX_DUAL)
		tr.tx_nbits = 2;
	if (mode & SPI_RX_QUAD)
		tr.rx_nbits = 4;
	else if (mode & SPI_RX_DUAL)
		tr.rx_nbits = 2;
	if (!(mode & SPI_LOOP)) {
		if (mode & (SPI_TX_QUAD | SPI_TX_DUAL))
			tr.rx_buf = 0;
		else if (mode & (SPI_RX_QUAD | SPI_RX_DUAL))
			tr.tx_buf = 0;
	}

	if (verbose && tx != NULL)
		hex_dump(tx, len, 32, "TX");

	ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1)
		pabort("can't send spi message");

	if (verbose && rx != NULL)
		hex_dump(rx, len, 32, "RX");
}

static void print_usage(const char *prog)
{
	printf("Usage: %s [-DsbdlHOLC3vpNR24SI]\n", prog);
	puts("  -D --device   device to use (default /dev/spidev1.1)\n"
	     "  -s --speed    max speed (Hz)\n"
	     "  -d --delay    delay (usec)\n"
	     "  -b --bpw      bits per word\n"
	     "  -o --output   output data to a file (e.g. \"results.bin\")\n"
	     "  -H --cpha     clock phase\n"
	     "  -O --cpol     clock polarity\n"
	     "  -L --lsb      least significant bit first\n"
	     "  -C --cs-high  chip select active high\n"
	     "  -3 --3wire    SI/SO signals shared\n"
	     "  -v --verbose  Verbose (show tx buffer)\n"
	     "  -N --no-cs    no chip select\n"
	     "  -S --size     number of bins to read\n"
		 "  -W --width    number of bits per bin\n"
	     "  -P --print    print decoded samples to stdout\n"
		 "  -e --decode   write decoded samples as txt instead of binary(not supported for -W above 64)\n"
		 "  -a --set-avg  after the readout, set the number of fft's to collect");
	exit(1);
}

static void parse_opts(int argc, char *argv[])
{
	while (1) {
		static const struct option lopts[] = {
			{ "device",  1, 0, 'D' },
			{ "speed",   1, 0, 's' },
			{ "delay",   1, 0, 'd' },
			{ "bpw",     1, 0, 'b' },
			{ "output",  1, 0, 'o' },
			{ "cpha",    0, 0, 'H' },
			{ "cpol",    0, 0, 'O' },
			{ "lsb",     0, 0, 'L' },
			{ "cs-high", 0, 0, 'C' },
			{ "3wire",   0, 0, '3' },
			{ "no-cs",   0, 0, 'N' },
			{ "verbose", 0, 0, 'v' },
			{ "fft size",    1, 0, 'S' },
			{ "fft width",    1, 0, 'W' },
			{ "print",0, 0, 'P' },
			{ "decode",0, 0, 'e' },
			{"set-avg", 1, 0, 'a'},
			{ NULL, 0, 0, 0 },
		};
		int c;

		c = getopt_long(argc, argv, "D:s:d:b:o:HOLC3NvS:W:na:",
				lopts, NULL);

		if (c == -1)
			break;

		switch (c) {
		case 'D':
			device = optarg;
			break;
		case 's':
			speed = atoi(optarg);
			break;
		case 'd':
			delay = atoi(optarg);
			break;
		case 'b':
			bits = atoi(optarg);
			break;
		case 'o':
			output_file = optarg;
			break;
		case 'H':
			mode |= SPI_CPHA;
			break;
		case 'O':
			mode |= SPI_CPOL;
			break;
		case 'L':
			mode |= SPI_LSB_FIRST;
			break;
		case 'C':
			mode |= SPI_CS_HIGH;
			break;
		case '3':
			mode |= SPI_3WIRE;
			break;
		case 'N':
			mode |= SPI_NO_CS;
			break;
		case 'v':
			verbose = 1;
			break;
		case 'S':
			num_bins = atoi(optarg);
			break;
		case 'W':
			bin_width = atoi(optarg);
			break;
		case 'P':
			print_samples = true;
			break;
		case 'e':
			write_decoded = true;
			break;
		case 'a':
			averages = atoi(optarg);
			set_averages = true;
			break;
		default:
			print_usage(argv[0]);
			break;
		}
	}
	if (mode & SPI_LOOP) {
		if (mode & SPI_TX_DUAL)
			mode |= SPI_RX_DUAL;
		if (mode & SPI_TX_QUAD)
			mode |= SPI_RX_QUAD;
	}
}


void decode_samples(uint8_t * buf, uint64_t * samples) {
	int i;
	uint numbytes = bin_width * num_bins / 8;
	int start_byte = 0;
	int start_bit = 0;
	for (i=0; i < num_bins; i++) {
		//printf("decoding sample %d: byte offset=%d, bit offset=%d\n", i, start_byte, start_bit);
		// calculate where this sample ends
		int end_bit = start_bit + bin_width;

		// calculate the 64 bit sample
		samples[i] = 0;
		int b;
		for (b=0; b<8; b++) {
			int index = start_byte + b;
			int byte  = index < numbytes ? buf[index] : 0;
			//printf("byte %d: %02X\n", index, byte);
			samples[i] += (uint64_t) byte << ((7 - b) * 8);
		}
		//printf("aggregate sample before bit operations: %016llX\n", samples[i]);
		// shift and mask the bits we want
		samples[i] >>= 64 - end_bit; // shift back
		//printf("aggregate sample after shifting: %016llX\n", samples[i]);
		uint64_t mask =  ((uint64_t)1 << bin_width)-1;
		samples[i] &= mask;
		//printf("final sample value after shift and truncate: %016llX\n", samples[i]);

		// increment counters
		start_byte += end_bit / 8;
		start_bit   = end_bit % 8;
	}
}

int main(int argc, char *argv[])
{
	printf("This is rd_fft_readout\n(c)Radboud Radio Lab\nAuthor: Sjoerd T. Timmer (s.timmer@astro.ru.nl)\n");
	printf("Compiled on %s at %s\n", __DATE__, __TIME__);

	int ret = 0;
	int fd;

	parse_opts(argc, argv);

	if (write_decoded && bin_width > 64) {
		pabort("Cannot decode integer larger than 64 bits");
	}

	fd = open(device, O_RDWR);
	if (fd < 0)
		pabort("can't open device");

	/*
	 * spi mode
	 */
	ret = ioctl(fd, SPI_IOC_WR_MODE32, &mode);
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

	printf("spi mode: 0x%x\n", mode);
	printf("bits per word: %d\n", bits);
	printf("max speed: %d Hz (%d KHz)\n", speed, speed/1000);


	int out_fd = open(output_file, O_WRONLY | O_CREAT | O_TRUNC, 0666);
	if (out_fd < 0)
		pabort("could not open output file");


	// calculate how many bytes to transfer since they are tightly packed in the spi transaction
	uint numbytes = 1 + bin_width * num_bins / 8; // one extra for the address
	uint8_t * buf = (uint8_t*)malloc(1 + numbytes);
	if (verbose)
		printf("%d fft bins of %d bits requires %d bytes\n", num_bins, bin_width, numbytes);

	// disable writing to spi capture buffer
	buf[0] = 0x0C; // select fft control reg
	buf[5] = 0x00;
	buf[6] = 0x00;
	buf[7] = 0x00;
	buf[8] = 0x00;
	buf[9] = 0b00000001; // request pause and select NS buffer
	transfer(fd, buf, buf, 10);

	// capture the old averages number if we are not going to overwrite it
	if (!set_averages) {
		averages = (buf[5] << 24) | (buf[6] << 16) | (buf[7] << 8) | buf[8];
		printf("keeping old averages value of %d\n", averages);
	} else {
		printf("setting new averages value to %d\n", averages);
	}

	// should take effect almost immediately
	// TODO: calculate worst possible delay

	// get the fft
	buf[0] = 0x0D; // select fft readout subsystem
	// remainder of buffer is don't care
	transfer(fd, buf, buf, numbytes);

	// unpack the tightly packed 18 bit samples into integers
	uint64_t * samples_ns;
	if (write_decoded) {
		samples_ns = malloc(num_bins * sizeof(uint64_t));
		decode_samples(buf+1, samples_ns);
		// actual writing happens later in this case
	} else if (output_file) {
		int ret = write(out_fd, buf + 1, numbytes-1);
		if (ret != numbytes-1)
			pabort("not all bytes written to output file");
	}

	// Select the EW channel, do not yet continue writing
	buf[0] = 0x0C; // select fft control reg
	buf[5] = 0x00;
	buf[6] = 0x00;
	buf[7] = 0x00;
	buf[8] = 0x00;
	buf[9] = 0b00000101; // request pause and select EW buffer
	transfer(fd, buf, buf, 10);

	// should take effect almost immediately
	// TODO: calculate worst possible delay

	// get the fft
	memset(buf, 0, numbytes);
	buf[0] = 0x0D; // select fft readout subsystem
	// remainder of buffer is don't care
	transfer(fd, buf, buf, numbytes);

	// unpack the tightly packed 18 bit samples into integers
	uint64_t * samples_ew;
	if (write_decoded) {
		samples_ew = malloc(num_bins * sizeof(uint64_t));
		decode_samples(buf+1, samples_ew);
	} else if (output_file) {
		int ret = write(out_fd, buf + 1, numbytes-1);
		if (ret != numbytes-1)
			pabort("not all bytes written to output file");
	}

	// print
	if (print_samples) {
		printf("              NS     EW\n");
		int i;
		for (i=0; i<num_bins; i++) {
			printf("fft[%3d]: %11llu %11llu\n", i, samples_ns[i], samples_ew[i]);
		}
	}

	// clear the fft buffer
	// disable writing to spi capture buffer
	buf[0] = 0x0C; // select fft control reg
	buf[5] = 0x00;
	buf[6] = 0x00;
	buf[7] = 0x00;
	buf[8] = 0x00;
	buf[9] = 0x03; // request clear
	transfer(fd, buf, buf, 10);

	// continue with taking fft's
	// disable writing to spi capture buffer
	buf[0] = 0x0C; // select fft control reg

	// set the averages number which is either what it was before or the new value
	buf[5] = (averages >> 24) & 0xFF;
	buf[6] = (averages >> 16) & 0xFF;
	buf[7] = (averages >>  8) & 0XFF;
	buf[8] = (averages      ) & 0xFF;

	buf[9] = 0x00; // clear all requests -> continue
	transfer(fd, buf, buf, 10);



	// todo: also read the number of fft's taken, need implementation on the fpga



	// write result
	if (output_file && write_decoded) {
		FILE * f = fopen(output_file, "w");
		int i;
		for (i=0; i< num_bins; i++) {
			fprintf(f, "%llu %llu\n", samples_ns[i], samples_ew[i]);
		}
		fclose(f);
	}




	close(fd);

	return ret;
}
