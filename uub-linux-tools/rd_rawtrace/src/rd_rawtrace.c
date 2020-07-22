
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
static int transfer_size;
static bool suppress_write = false;
static bool do_print_samples = false;

//#define CHUNKSIZE 2048
#define CHUNKSIZE 988
// CHUNKSIZE needs to be divisible by 52 because the vhdl module can't deal with partial sample readout
// CHUNKSIZE needs to be less than 4095 because the maximum spi buffer size on the zynq in 4096 (and we need 1 addr byte)


char *input_tx;

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
	int out_fd;

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
	     "  -S --size     transfer size\n"
	     "  -n --no-write suppress spi transactions that force a write period\n"
		 "  -P --do-print also print the sample values as ascii to stdout\n");
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
			{ "size",    1, 0, 'S' },
			{ "no-write",0, 0, 'n' },
			{ "do-print",0, 0, 'P' },
			{ NULL, 0, 0, 0 },
		};
		int c;

		c = getopt_long(argc, argv, "D:s:d:b:o:HOLC3NvS:nP",
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
			transfer_size = atoi(optarg);
			break;
		case 'n':
			suppress_write = true;
			break;
		case 'P':
			do_print_samples = true;
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

static uint64_t _read_count;
static uint64_t _write_count;


int main(int argc, char *argv[])
{
	printf("This is rd_rawtrace\n(c)Radboud Radio Lab\nAuthor: Sjoerd T. Timmer (s.timmer@astro.ru.nl)\n");
	printf("Compiled on %s at %s\n", __DATE__, __TIME__);

	int ret = 0;
	int fd;

	parse_opts(argc, argv);

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

	uint8_t * buf = (uint8_t*)malloc(CHUNKSIZE + 1);

	if (!suppress_write)
	{
		// enable writing to spi capture buffer
		buf[0] = 0x0B; // command to active spi readout
		buf[1] = 0x01;
		transfer(fd, buf, NULL, 2);

		// not strictly needed because transactions should take more than enough time to fill our buffer
		 usleep(1000); // sleep at least 8.192 us (time to fill the buffer)

		// disable writing to spi capture buffer
		buf[0] = 0x0B; // command to active spi readout
		buf[1] = 0x00;
		transfer(fd, buf, NULL, 2);
	}

	// do the actual transfer: make sure to continue writing zero's to the write_enable register
	// otherwise data would start to be overwritten before everything is read out:
	int num_transfers = 1 + ((transfer_size-1) / CHUNKSIZE); // implicit ceil
	int i;
	for (i=0; i<num_transfers; i++) {
		int chunksize = CHUNKSIZE;
		if (transfer_size - i * CHUNKSIZE < chunksize) chunksize = transfer_size - i * CHUNKSIZE;
		printf("Transferring chunk %d of %d: %d bytes\n", i, num_transfers, chunksize);

		memset(buf, 0, CHUNKSIZE + 1);
		buf[0] = 0x0B;
		transfer(fd, buf, buf, chunksize+1); // note that this overwrites the buffer

		int ret = write(out_fd, buf + 1, chunksize);
		if (ret != chunksize)
			pabort("not all bytes written to output file");

		// unpack the tightly packed 13 bit samples into integers
		int samples_in_chunk = chunksize * 8 / 13;
		// the shifts are a bit hard to calculate, but fortunately they repeat every 8 samples
		int shifts[8] = {11, 6, 9, 4, 7, 10, 5, 8};
		int * samples = malloc(samples_in_chunk * sizeof(int));
		int j;
		for (j=0; j<samples_in_chunk; j++) {
			int start_bit  = 13 * j;
			int start_byte = start_bit / 8;
			int x1 = buf[1 + start_byte + 0];
			int x2 = buf[1 + start_byte + 1];
			int x3 = buf[1 + start_byte + 2];
			int shift = shifts[j % 8];
			int mask  = 0x0FFF;
			int s = (((x1 << 16) + (x2 << 8) + x3) >> shift) & mask;
			samples[j] = s;
			//printf("decoding bytes %d-%d");
		}

		// print
		if (do_print_samples) {
			printf("    NS     EW\n");
			for (j=0; j<samples_in_chunk; j++) {
				int s = samples[j] > 2047 ? samples[j] - 4096 : samples[j];
				if (j%2 == 0) {
					printf("%6d", s);
				} else {
					printf(" %6d\n", s);
				}

			}
		}
	}

	close(out_fd);

	close(fd);

	return ret;
}
