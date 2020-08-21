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

#define MIN(A,B) ((A)<(B)?(A):(B))

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

static bool set_max     = false;
static bool set_thres   = false;
static bool set_stretch = false;

static uint16_t quiet_thres   = 7;
static uint16_t quiet_stretch = 0;
static uint32_t fft_count     = 0;
static uint32_t max_fft       = 2 * 1;
static uint32_t fft_timer     = 0;
static uint16_t read_offset   = 0;
static uint8_t  status_reg    = 0x00;

#define STATUS_MASK 0b10000000
#define REQ_PAUSE  (1 << 0)
#define REQ_CLEAR  (1 << 1)
#define READ_NS    (0 << 2)
#define READ_EW    (1 << 2)
#define FFT_BUSY   (1 << 7)

#define SUBSYSTEM_ADDR_CONTROL 0x0C
#define SUBSYSTEM_ADDR_READOUT 0x0D


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
	printf("Usage: %s [-DsbdlHOLC3vpNR24SItT]\n", prog);
	puts("  -D --device      device to use (default /dev/spidev1.1)\n"
	     "  -s --speed       max speed (Hz)\n"
	     "  -d --delay       delay (usec)\n"
	     "  -b --bpw         bits per word\n"
	     "  -o --output      output data to a file (e.g. \"results.bin\")\n"
	     "  -H --cpha        clock phase\n"
	     "  -O --cpol        clock polarity\n"
	     "  -L --lsb         least significant bit first\n"
	     "  -C --cs-high     chip select active high\n"
	     "  -3 --3wire       SI/SO signals shared\n"
	     "  -v --verbose     Verbose (show tx buffer)\n"
	     "  -N --no-cs       no chip select\n"
	     "  -S --size        number of bins to read\n"
		 "  -W --width       number of bits per bin\n"
	     "  -P --print       print decoded samples to stdout\n"
		 "  -m --set-max     after the readout, set the number of fft's to collect\n"
		 "  -t --set-thres   set the threshold for quiet region selection\n"
         "  -T --set-stretch set the number of clock cycles to stretch the quiet area\n" );
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
			{"set-max", 1, 0, 'm'},
			{"set-thres", 1, 0, 't'},
			{ NULL, 0, 0, 0 },
		};
		int c;

		c = getopt_long(argc, argv, "D:s:d:b:o:HOLC3NvS:W:Pm:t:T:",
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
		case 'm':
			max_fft = atoi(optarg);
			set_max = true;
			break;
		case 't':
			quiet_thres = atoi(optarg);
			set_thres = true;
			break;
        case 'T':
			quiet_stretch = atoi(optarg);
			set_stretch = true;
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

void update_control_register(int fd, bool verbose) {
	// alocate buffer
	uint8_t * buf = (uint8_t*)malloc(20);

	// populate buffer
	buf[ 0] = SUBSYSTEM_ADDR_CONTROL;        // select fft control registers
	buf[ 1] = (quiet_thres >> 8) & 0xFF;
	buf[ 2] = (quiet_thres >> 0) & 0xFF;
	buf[ 3] = (quiet_stretch >> 8) & 0xFF;
	buf[ 4] = (quiet_stretch >> 0) & 0xFF;
    buf[ 5] = (max_fft >> 24) & 0xFF;
	buf[ 6] = (max_fft >> 16) & 0xFF;
	buf[ 7] = (max_fft >>  8) & 0xFF;
	buf[ 8] = (max_fft >>  0) & 0xFF;
    buf[ 9] = 0; // count is read only anyway
	buf[10] = 0; 
	buf[11] = 0; 
	buf[12] = 0; 
    buf[13] = 0; // timer is read only anyway
	buf[14] = 0;
	buf[15] = 0;
	buf[16] = 0;
	buf[17] = (read_offset >> 8) & 0xFF;
	buf[18] = (read_offset >> 0) & 0xFF;
	buf[19] = status_reg;

	// Do the actual transfer
	transfer(fd, buf, buf, 20);

	// capture the old averages number if we are not going to overwrite it
    uint32_t oldmax = (buf[5] << 24) | (buf[6] << 16) | (buf[7] << 8) | buf[8];
    uint32_t old_thres = (buf[1] << 8) | buf[2];
    uint32_t old_stretch = (buf[3] << 8) | buf[4];
    
    if (set_max) {
        if (verbose) {
            printf("Updating max fft from %d to %d\n", oldmax, max_fft);
        }
    } else {
		max_fft = oldmax;
        if (verbose) {
            printf("Leaving max fft at %d\n", oldmax);
        }
	}
	// capture the old averages number if we are not going to overwrite it
	if (set_thres) {
        if (verbose) {
            printf("Updating threshold from %d to %d\n", old_thres, quiet_thres);
        }
    } else {
		quiet_thres = old_thres;
        if (verbose) {
            printf("Leaving threshold at %d\n", old_thres);
        }
	}
    // capture the old quiet stretch if we are not going to overwrite it
    if (set_stretch) {
        if (verbose) {
            printf("Updating stretch from %d to %d\n", old_stretch, quiet_stretch);
        }
    }else {
        quiet_stretch = old_stretch;
        printf("Leaving quiet stretch at %d\n", old_stretch);
    }
    
	// capture the fft_count
	fft_count = (buf[9] << 24) | (buf[10] << 16) | (buf[11] << 8) | buf[12];
    
    // capture timer counter
    fft_timer = (buf[13] << 24) | (buf[14] << 16) | (buf[15] << 8) | buf[16];
    
	// capture busy bit
	status_reg = (status_reg & ~STATUS_MASK) | (buf[19] & STATUS_MASK);

	// should take effect almost immediately
	// TODO: calculate worst possible delay

	free(buf);
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


void read_samples(int fd, uint8_t* target_buffer, int offset, int count, int which_buffer) {
	// calculate how many bytes to transfer since they are tightly packed in the spi transaction
	uint numbytes = 1 + bin_width * count / 8; // one extra for the address

	// select channel and set read start offset
	status_reg = REQ_PAUSE | which_buffer;
	read_offset = offset;
	update_control_register(fd, false);

	// create a transfer buffer
	uint8_t * buf = (uint8_t*) malloc(numbytes);
	memset(buf, 0, numbytes); // not required but nice for debug
	buf[0] = SUBSYSTEM_ADDR_READOUT;

		// do the data transfer
	transfer(fd, buf, buf, numbytes);

	// store the result
	memcpy(target_buffer + offset * bin_width / 8, buf + 1, numbytes - 1);
}


int main(int argc, char *argv[])
{
	printf("This is rd_fft_readout\n(c)Radboud Radio Lab\nAuthor: Sjoerd T. Timmer (s.timmer@astro.ru.nl)\n");
	printf("Compiled on %s at %s\n", __DATE__, __TIME__);

	int ret = 0;
	int fd;

	parse_opts(argc, argv);

	if (print_samples && bin_width > 64) {
		pabort("Cannot decode integer larger than 64 bits");
	}

	if (num_bins % 8 != 0) {
		printf("fft size not a multiple of 8. This case was not anticipated and is likely to cause issues.\n");
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
	printf("number of fft bins to download: %d\n", num_bins);
	printf("bits per fft bin: %d\n", bin_width);

	int out_fd;
	if (output_file) {
		out_fd = open(output_file, O_WRONLY | O_CREAT | O_TRUNC, 0666);
		if (out_fd < 0)
			pabort("could not open output file");

		// write a little header
		write(out_fd, __DATE__, strlen(__DATE__));
		write(out_fd, " ", 1);
		write(out_fd, __TIME__, strlen(__TIME__));
	}

	// request the fft engine to pause making more fft during readout
	status_reg = REQ_PAUSE;
	update_control_register(fd, true);
    if (verbose) {
        printf("current settings:\n");
        if (!set_max)
            printf("  max fft: %d\n", max_fft);
        if (!set_thres)
            printf("  quiet thres: %d\n", quiet_thres);
        if (!set_stretch)
            printf("  quiet stretch: %d\n", quiet_stretch);
    }
    
	printf("%d fft's captured in %d ms\n", fft_count, fft_timer);

	// in order to decode them we need to store all samples as raw binary first because we are going to get them as chunks
	uint8_t * raw_data_ns = (uint8_t *) malloc(bin_width * num_bins / 8);
	uint8_t * raw_data_ew = (uint8_t *) malloc(bin_width * num_bins / 8);

	// 8 samples always aligns with bytes
	// we can get 4095 bytes at most in one transaction
	// so we need the largest multiple of 8 that still fits
	int max_samples = 8 * (4095 / bin_width);
	printf("max_samples: %d\n", max_samples);
	int chan = 0;
	for (chan=0; chan < 2; chan++) {
		int offset = 0;
		while (offset < num_bins) {
			int count  = MIN(max_samples, num_bins - offset);
			printf("reading %d samples at offset %d from channel %d\n", count, offset, chan);
			if (chan == 0)
				read_samples(fd, raw_data_ns, offset, count, READ_NS);
			else
				read_samples(fd, raw_data_ew, offset, count, READ_EW);
			offset += count;
		}
	}

	// unpack the tightly packed bit samples into integers
	if (print_samples) {
		uint64_t * samples_ns = malloc(num_bins * sizeof(uint64_t));
		uint64_t * samples_ew = malloc(num_bins * sizeof(uint64_t));
		decode_samples(raw_data_ns, samples_ns);
		decode_samples(raw_data_ew, samples_ew);
		printf("              NS     EW\n");
		int i;
		for (i=0; i<num_bins; i++) {
			printf("fft[%3d]: %11llu %11llu\n", i, samples_ns[i], samples_ew[i]);
		}
	}

	// write to file
	if (output_file) {
		// write the fft count
		unsigned char bytes[4];
		bytes[0] = fft_count >> 24 & 0xFF;
		bytes[1] = fft_count >> 16 & 0xFF;
		bytes[2] = fft_count >>  8 & 0xFF;
		bytes[3] = fft_count >>  0 & 0xFF;
		write(out_fd, bytes, 4);

		// write the time
		int now = time(NULL);
		printf("Curring unix time: %d\n", now);
		bytes[0] = now >> 24 & 0xFF;
		bytes[1] = now >> 16 & 0xFF;
		bytes[2] = now >>  8 & 0xFF;
		bytes[3] = now >>  0 & 0xFF;
		write(out_fd, bytes, 4);


		// write the samples themselves
		int numbytes = bin_width * num_bins / 8;
		int ret;
		ret = write(out_fd, raw_data_ns, numbytes);
		if (ret != numbytes)
			pabort("not all bytes written to output file");
		ret = write(out_fd, raw_data_ew, numbytes);
		if (ret != numbytes)
			pabort("not all bytes written to output file");
		close(out_fd);
	}

	// clear the fft buffer
	// disable writing to spi capture buffer
	status_reg = REQ_PAUSE | REQ_CLEAR; // NS and EW are cleared together
	update_control_register(fd, false);

	// unpause fft engine
	status_reg = 0x00;
	update_control_register(fd, false);

	close(fd);

	return ret;
}
