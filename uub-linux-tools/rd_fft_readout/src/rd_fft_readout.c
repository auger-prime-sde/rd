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
static int num_bins  = 512;
static int bin_width = 64;
static bool print_samples = false;

static uint16_t * set_thres   = NULL;
static uint16_t * set_stretch = NULL;
static uint32_t * set_max     = NULL;


//static bool set_max     = false;
//static bool set_thres   = false;
//static bool set_stretch = false;
//
//static uint16_t quiet_thres   = 7;
//static uint16_t quiet_stretch = 0;
//static uint32_t fft_count     = 0;
//static uint32_t max_fft       = 2 * 1;
//static uint32_t fft_timer     = 0;
//static uint16_t read_offset   = 0;
//static uint8_t  status_reg    = 0x00;

typedef struct {
	uint16_t quiet_thres;
	uint16_t quiet_stretch;
	uint32_t fft_count;
	uint32_t max_fft;
	uint32_t fft_timer;
	uint16_t read_offset;
	uint8_t  status;
} control_register_type;


control_register_type old_control_register, new_control_register;

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
			set_max = (uint32_t*)malloc(sizeof(uint32_t));
			*set_max = atoi(optarg);
			break;
		case 't':
			set_thres = (uint16_t*)malloc(sizeof(uint16_t));
			*set_thres = atoi(optarg);
			break;
        case 'T':
			set_stretch = (uint16_t*)malloc(sizeof(uint16_t));
			*set_stretch = atoi(optarg);
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


void update_control_register(int fd, control_register_type * old, control_register_type * new) {
	// allocate buffer
	uint8_t * buf = (uint8_t*)malloc(20);

	// allow empty new data
	control_register_type default_values = {};
	if (new == NULL) {
		new = &default_values;
	}

	// populate buffer
	buf[ 0] = SUBSYSTEM_ADDR_CONTROL;        // select fft control registers
	buf[ 1] = (new->quiet_thres >> 8) & 0xFF;
	buf[ 2] = (new->quiet_thres >> 0) & 0xFF;
	buf[ 3] = (new->quiet_stretch >> 8) & 0xFF;
	buf[ 4] = (new->quiet_stretch >> 0) & 0xFF;
    buf[ 5] = (new->max_fft >> 24) & 0xFF;
	buf[ 6] = (new->max_fft >> 16) & 0xFF;
	buf[ 7] = (new->max_fft >>  8) & 0xFF;
	buf[ 8] = (new->max_fft >>  0) & 0xFF;
    buf[ 9] = 0; // count is read only anyway
	buf[10] = 0; 
	buf[11] = 0; 
	buf[12] = 0; 
    buf[13] = 0; // timer is read only anyway
	buf[14] = 0;
	buf[15] = 0;
	buf[16] = 0;
	buf[17] = (new->read_offset >> 8) & 0xFF;
	buf[18] = (new->read_offset >> 0) & 0xFF;
	buf[19] = new->status;

	// Do the actual transfer
	transfer(fd, buf, buf, 20);

	// Capture old values
	if (old != NULL)
	{
		old->quiet_thres   = (buf[ 1] <<  8) | buf[2];
		old->quiet_stretch = (buf[ 3] <<  8) | buf[4];
		old->max_fft       = (buf[ 5] << 24) | (buf[ 6] << 16) | (buf[ 7] << 8) | buf[ 8];
		old->fft_count     = (buf[ 9] << 24) | (buf[10] << 16) | (buf[11] << 8) | buf[12];
		old->fft_timer     = (buf[13] << 24) | (buf[14] << 16) | (buf[15] << 8) | buf[16];
		old->read_offset   = (buf[17] <<  8) | buf[18];
		old->status        = buf[19];
	}

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
	new_control_register.status = REQ_PAUSE | which_buffer;
	new_control_register.read_offset = offset;
	update_control_register(fd, NULL, &new_control_register);

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
	new_control_register.status = REQ_PAUSE;
	update_control_register(fd, &old_control_register, &new_control_register);

	// copy old to new
	new_control_register = old_control_register;

	// apply requested changes
	if (set_max != NULL)
	{
		new_control_register.max_fft = *set_max;
	}
	if (set_thres != NULL)
	{
		new_control_register.quiet_thres = *set_thres;
	}
	if (set_stretch != NULL)
	{
		new_control_register.quiet_stretch = *set_stretch;
	}

	// print what is happening
    if (verbose) {
        printf("Status register: old\tnew:\n");
        printf("threshold:       %d\t%d\n", old_control_register.quiet_thres, new_control_register.quiet_thres);
        printf("stretch:         %d\t%d\n", old_control_register.quiet_stretch, new_control_register.quiet_stretch);
        printf("max fft's:       %d\t%d\n", old_control_register.max_fft, new_control_register.max_fft);
        // for control only print the old value
        printf("control:         0x%x\n", old_control_register.status);
    }
    
	printf("%d fft's captured in %d ms\n", old_control_register.fft_count, old_control_register.fft_timer);

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
		// write the time:
		int now = time(NULL);
		printf("Curring unix time: %d\n", now);
		unsigned char bytes[4];
		bytes[0] = now >> 24 & 0xFF;
		bytes[1] = now >> 16 & 0xFF;
		bytes[2] = now >>  8 & 0xFF;
		bytes[3] = now >>  0 & 0xFF;
		write(out_fd, bytes, 4);

		// write the status and control reg, all of it for good measure:
		write(out_fd, &old_control_register, sizeof(control_register_type));

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
	new_control_register.status = REQ_PAUSE | REQ_CLEAR; // NS and EW are cleared together
	update_control_register(fd, NULL, &new_control_register);

	// unpause fft engine
	new_control_register.status = 0x00;
	update_control_register(fd, NULL, &new_control_register);

	close(fd);

	return ret;
}
