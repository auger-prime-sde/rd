/*
 * Auger RD flash tool (using spidev driver)
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
#include <sys/mman.h>
#include <sys/stat.h>

#define DIG_IFC_BASE 0x43c80000

#define DIG_IFC_CONTROL 0
#define DIG_IFC_INPUT   1
#define DIG_IFC_OUTPUT  2
#define DIG_IFC_ID      3

#define PAGE_SIZE 256
#define SECTOR_SIZE 4096

// end addresses are exclusive
// we don't use non-volatile write protection so we can put all blocks back-to-back
// 0x0B0000 is the theoretical maximum size of a bitstream size
#define PRIMARY_PATTERN_START 0x000000
#define PRIMARY_PATTERN_END   0x0B0000
// golden pattern follows primary immediately
#define GOLDEN_PATTERN_START  0x0B0000
#define GOLDEN_PATTERN_END    0x160000
// user data follows golden pattern immediately
#define USER_DATA_START       0x160000
#define USER_DATA_END         0x3FF000
// small gap to align with 4k eraseable sectors
// the last 256-byte page must contain the jump command
#define JUMP_COMMAND_START    0x3FFF00
#define JUMP_COMMAND_END      0x3FFFFF

static void pabort(const char *s)
{
	perror(s);
	abort();
}

static const char *device = "/dev/spidev32765.0";
static uint32_t mode = SPI_CPHA | SPI_CPOL;
static uint8_t bits = 8;
static uint32_t speed = 1000000;
static uint16_t delay = 0;
static bool verbose = false;
static uint32_t chunksize = 1024;
static bool print_chipid = false;
static bool print_bpr = false;
static bool print_firmwareid = false;
static bool enable_dig_ifc = false;
static bool do_write_jump_addr = false;

static char *primary_input = NULL;
static char *golden_input = NULL;
static char *userdata_input = NULL;
static char *primary_output = NULL;
static char *golden_output = NULL;
static char *userdata_output = NULL;
static char *chip_output = NULL;




static void hex_dump(const void *src, size_t length, size_t line_size,  char *prefix)
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

static void transfer(int fd, uint8_t const *tx, uint8_t const *rx, size_t len, bool verbose)
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

	if (verbose && tx)
		hex_dump(tx, len, 32, "TX");

	ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1)
		pabort("can't send spi message");

	if (verbose && rx)
		hex_dump(rx, len, 32, "RX");
}

static void verify_chip_id(int fd)
{
	uint8_t buf[] = {
		0x02, // select flash subsystem
		0x9F, // get JEDEC id
		0x00, // space for response
		0x00, // space for response
		0x00  // space for response
	};

	transfer(fd, buf, buf, sizeof(buf), verbose);

	// abort when response is not correct
	if (verbose || print_chipid)
		printf("Chip id: 0x%02X 0x%02X 0x%02X\nShould be: 0xBF 0x26 0x42\n", buf[2], buf[3], buf[4]);
	if (buf[2] != 0xBF || buf[3] != 0x26 || buf[4] != 0x42)
	{
		printf("Bad chip id received!\n");
		abort();
	}
}

static void print_usage(const char *prog)
{
	printf("Usage: %s [-Dsvcibfrguaw]\n", prog);
	puts("  -D --device         device to use (default /dev/spidev32765.0)\n"
	     "  -s --speed          max speed (Hz)\n"
	     "  -v --verbose        verbose output\n"
		 "  -c --chunksize      chunksize (for reading only, default 1024)\n"
		 "  -i --flashid        print flash id\n"
	     "  -b --bpr            read and print the volatile block protection register\n"
		 "  -f --firmwareid     print currently running RD firmware number\n"
	     "     --enable-dig-ifc enable real pin io if not already enabled by writing bit 16 in DIG_IFC_CONTROL register\n"
		 "  -r --dump-primary   file to write primary pattern to\n"
		 "  -g --dump-golden    file to write golden pattern to\n"
		 "  -u --dump-user      file to write user data to\n"
		 "  -a --dump-all       dump entire memory including the golden image, user data and jump command\n"
		 "  -w --prog-primary   overwrite primary pattern with file contents\n"
		  );
	exit(1);
}

static void parse_opts(int argc, char *argv[])
{

	while (1) {
		static const struct option lopts[] = {
			{ "device",        required_argument, NULL, 'D' },
			{ "speed",         required_argument, NULL, 's' },
			{ "verbose",       no_argument,       NULL, 'v' },
			{ "chunksize",     required_argument, NULL, 'c' },
			{ "flashid",       no_argument,       NULL, 'i' },
			{ "bpr",           no_argument,       NULL, 'b' },
			{ "firmareid",     no_argument,       NULL, 'f' },
			{ "enable-dig-ifc",no_argument,       NULL, 'e' },
			{ "dump-primary",  required_argument, NULL, 'r' },
			{ "dump-golden",   required_argument, NULL, 'g' },
			{ "dump-user",     required_argument, NULL, 'u' },
			{ "dump-all",      required_argument, NULL, 'a' },
			{ "prog-primary",  required_argument, NULL, 'w' },
			// some more undocumented methods for developers only
			{ "prog-golden",   required_argument, NULL, 'G' },
			{ "prog-user",     required_argument, NULL, 'U' },
			{ "write-jump-cmd",no_argument,       NULL, 'J' },
			{ NULL,            no_argument,       NULL, NULL}
		};
		int c;

		c = getopt_long(argc, argv, "D:s:c:vibfr:g:u:w:a:G:U:J", lopts, NULL);

		if (c == -1)
			break;

		switch (c) {
		case 'D':
			device = optarg;
			break;
		case 's':
			speed = atoi(optarg);
			break;
		case 'c':
			chunksize = atoi(optarg);
			break;
		case 'v':
			verbose = 1;
			break;
		case 'i':
			print_chipid = true;
			break;
		case 'b':
			print_bpr = true;
			break;
		case 'f':
			print_firmwareid = true;
			break;
		case 'e':
			enable_dig_ifc = true;
			break;
		case 'r':
			primary_output = optarg;
			break;
		case 'g':
			golden_output = optarg;
			break;
		case 'u':
			userdata_output = optarg;
			break;
		case 'a':
			chip_output= optarg;
			break;
		case 'w':
			primary_input = optarg;
			break;
		case 'G':
			golden_input = optarg;
			break;
		case 'U':
			userdata_input = optarg;
			break;
		case 'J':
			do_write_jump_addr = true;
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

void verify_dig_ifc()
{
	int fd = open("/dev/mem", O_RDWR);
	uint32_t * dig = (uint32_t*) mmap(NULL, 4*sizeof(uint32_t), PROT_READ|PROT_WRITE, MAP_SHARED, fd, DIG_IFC_BASE);

	if (dig == MAP_FAILED) {
		printf("map failed, could not verify DIG_IFC_CONTROL register\n");
		return;
	}

	if ((dig[DIG_IFC_CONTROL] & 0x10000) == 0) {
		printf( "DIG_IFC_CONTROL bit 16 is set to 0, which indicates factory test mode.\n");
		if (enable_dig_ifc)
		{
			dig[DIG_IFC_CONTROL] |= 0x10000;
			printf("DIG_IFC_CONTROL updated\n");
		}
		else
		{
			abort();
		}
	}
}


uint8_t reverse_bits(uint8_t inp)
{
	uint8_t res = 0;
	int i;
	for (i=0; i < 8; i++)
	{

		res += ((inp >> i) & 0x01 ) << (7-i);
	}
	return res;
}
void write_jump_addr(int fd)
{
	/* According to the Multi boot documentation of the ECP5 the JUMP command should look like this:
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF (8 dummy bytes)
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF (8 dummy bytes)
	 * 0xBD 0xB3                               (2 byes preable)
	 * 0xC4 0x00 0x00 0x00 0x00 0x00 0x00 0x00 (1 byte Control Register, 3 bytes Command info, 4 bytes Control data)
	 * 0xFE 0x00 0x00 0x00 [  ] [            ] (1 byte Jump command, 3 bytes command info, 1 byte spi mode(0x03 for normal speed), 3 bytes address)
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF (8 dummy bytes)
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF (8 dummy bytes)
	 *
	 * Note that the bytes are all stored big-endian so reversed from the 'normal' data
	 *
	 * However, when inspecting a JUMP sector generated by lattice it appears as follows:
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF 0xBD 0xCD 0xFF 0xFF 0xFF 0xFF (..preable....?)
	 * 0x7E 0x00 0x00 0x00 0xC0 0xD0 0x00 0x00 (.....[reversed addr])
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF
	 *
	 * The above is generated with the Lattice advance spi flash tool
	 * When generating with the Dual boot tool you get this: It appears that the bit-order is reversed
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF 0xBD 0xB3 0xFF 0xFF 0xFF 0xFF
	 * 0x7E 0x00 0x00 0x00 0x03 0x0B 0x00 0x00
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 * 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF 0xFF
	 *
	 */

	// prepare an empty buffer
	uint8_t buf[256+5];
	uint8_t jmp[256];
	memset(&jmp, 0xFF, sizeof(jmp));

	jmp[18] = 0xBD;
	jmp[19] = 0xB3;
	jmp[24] = 0x7E;
	jmp[25] = 0x00;
	jmp[26] = 0x00;
	jmp[27] = 0x00;
	jmp[28] = 0x03;
	jmp[29] = (GOLDEN_PATTERN_START >> 16) & 0xFF;
	jmp[30] = (GOLDEN_PATTERN_START >>  8) & 0xFF;
	jmp[31] = (GOLDEN_PATTERN_START      ) & 0xFF;


	// write enable:
	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x06; // Write enable
	transfer(fd, buf, NULL, 2, verbose);

	// sector erase:
	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x20; // sector erase
	buf[2] = (JUMP_COMMAND_START >> 16) & 0xFF; // word 3 of addr
	buf[3] = (JUMP_COMMAND_START >>  8) & 0xFF; // word 2 of addr
	buf[4] = (JUMP_COMMAND_START      ) & 0xFF; // word 1 of addr
	transfer(fd, buf, NULL, 5, verbose);
	usleep(25000);

	// write enable:
	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x06; // Write enable
	transfer(fd, buf, NULL, 2, verbose);

	// prepare page program
	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x02; // page program command of spi flash
	buf[2] = (JUMP_COMMAND_START >> 16) & 0xFF; // word 3 of addr
	buf[3] = (JUMP_COMMAND_START >>  8) & 0xFF; // word 2 of addr
	buf[4] = (JUMP_COMMAND_START      ) & 0xFF; // word 1 of addr
	memcpy(buf+5, jmp, 256);

	// do the spi transfer
	transfer(fd, buf, NULL, 5+256, verbose);

	// page program takes at most 1.5ms
	usleep(1500);


	// TODO: verify

}


void write_from_file(int fd, int start, int end, char* filename)
{
	// get file size:
	struct stat st;
	if (stat(filename, &st) != 0)
	{
		pabort("Failed to get file size");
	}
	int filesize = st.st_size;

	if (filesize >= end - start)
	{
		printf("WARNING: file size is larger than reserved space for this section. File will be truncated!\n");
		filesize = end - start;
	}

	int numpages = 1 + (filesize - 1) / PAGE_SIZE;
	if (verbose)
		printf("Writing %d bytes in %d chunks of %d\n", filesize, numpages, PAGE_SIZE);

	// prepare tx buffer (we use the same buffer for tx and rx)
	uint8_t* buf = malloc(5 + PAGE_SIZE);

	// prepare output file
	FILE * file = fopen(filename, "rb");
	if (!file)
		pabort("could not open input file");


	// Erase necessary sectors:
	int start_sector = start / SECTOR_SIZE;
	int end_sector   = end   / SECTOR_SIZE;
	int sector;
	for (sector=start_sector; sector<end_sector; ++sector)
	{
		// write enable:
		buf[0] = 0x02; // select flash subsystem
		buf[1] = 0x06; // Write enable
		transfer(fd, buf, NULL, 2, verbose);

		// sector erase:
		int offset = sector * SECTOR_SIZE;
		buf[0] = 0x02; // select flash subsystem
		buf[1] = 0x20; // sector erase
		buf[2] = (offset >> 16) & 0xFF; // word 3 of addr
		buf[3] = (offset >>  8) & 0xFF; // word 2 of addr
		buf[4] = (offset      ) & 0xFF; // word 1 of addr
		transfer(fd, buf, NULL, 5, verbose);

		// TODO: verify if chip is ready for next, sector erase can take upto 25ms
		usleep(25000);

		// print progress
		printf("\rErasing 0x%06X-0x%06X: %d/%d sectors erased", start, end, sector - start_sector + 1, end_sector - start_sector);
		fflush(stdout);
	}
	printf("\n");

	int page;
	for (page=0 ; page < numpages ; ++page)
	{
		// calculate offset
		int offset = page * PAGE_SIZE;

		// calculate size of current page
		int pagesize = filesize - offset;
		if (pagesize > PAGE_SIZE) pagesize = PAGE_SIZE;

		// enable writes:
		buf[0] = 0x02; // select flash subsystem
		buf[1] = 0x06; // Write enable
		transfer(fd, buf, NULL, 2, verbose);

		// prepare page program
		buf[0] = 0x02; // select flash subsystem
		buf[1] = 0x02; // page program command of spi flash
		buf[2] = ((start + offset) >> 16) & 0xFF; // word 3 of addr
		buf[3] = ((start + offset) >>  8) & 0xFF; // word 2 of addr
		buf[4] = ((start + offset)      ) & 0xFF; // word 1 of addr

		// read 256 bytes from file
		int numread = fread(buf + 5, 1, pagesize, file);
		if (numread < pagesize)
		{
			printf("\nError: File read failed at offset %d\n", offset);
		}

		// do the spi transfer
		transfer(fd, buf, NULL, 5+pagesize, verbose);

		// page program takes at most 1.5ms
		usleep(1500);

		// print progress:
		printf("\rWriting: %5.2f%%", 100.0 * (page + 1) / numpages);
		fflush(stdout);
	}
	printf("\n");

	// clean up
	fclose(file);
	free(buf);
}


#define bitval(buf, bit) ((buf[9-(bit)/8] >> ((bit) % 8)) & 0x01)
void read_block_protection_register(int fd, uint8_t* bpr)
{
	// prepare tx buffer (we use the same buffer for tx and rx)
	uint8_t* buf = malloc(12); // 1 select byte, 1 command byte, 10 response bytes for 80 block protection bits

	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x72; // Read block protection register
	transfer(fd, buf, buf, 12, verbose);

	memcpy(bpr, buf + 2, 10);
	free(buf);
}

void write_block_protection_register(int fd, uint8_t* bpr)
{
	// prepare tx buffer (we use the same buffer for tx and rx)
	uint8_t* buf = malloc(12); // 1 select byte, 1 command byte, 10 response bytes for 80 block protection bits

	// enable writes
	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x06; // write enabe
	transfer(fd, buf, NULL, 2, verbose);

	// write new bpr
	buf[0] = 0x02; // select flash subsystem
	buf[1] = 0x42; // Write block protection register
	memcpy(buf+2, bpr, 10);
	transfer(fd, buf, NULL, 12, verbose);

	free(buf);
}

void print_block_protection_register(uint8_t* bpr)
{
	int i;
	for (i=0; i<10; i++)
	{
		printf("0x%02X ", bpr[i]);
	}
	printf("\n");
	if (verbose)
	{
		printf("write locks: \n");
		// see SST26VF032B datasheet for layout of bit protection register
		printf("0x000000-0x001FFF: %s\n", bitval(bpr, 64)?"protected":"unprotected");
		printf("0x002000-0x003FFF: %s\n", bitval(bpr, 66)?"protected":"unprotected");
		printf("0x004000-0x005FFF: %s\n", bitval(bpr, 68)?"protected":"unprotected");
		printf("0x006000-0x007FFF: %s\n", bitval(bpr, 70)?"protected":"unprotected");
		printf("0x008000-0x00FFFF: %s\n", bitval(bpr, 62)?"protected":"unprotected");
		// there are 62 linearly spaced blocks in the middle
		int i;
		for (i=0; i < 62; i++)
		{
			printf("0x%06X-0x%06X: %s\n",
					0x010000 + 0x010000 * i,
					0x01FFFF + 0x010000 * i,
					bitval(bpr, i)?"protected":"unprotected"  );
		}
		printf("0x3F0000-0x3F7FFF: %s\n", bitval(bpr, 63)?"protected":"unprotected");
		printf("0x3F8000-0x3F9FFF: %s\n", bitval(bpr, 72)?"protected":"unprotected");
		printf("0x3FA000-0x3FBFFF: %s\n", bitval(bpr, 74)?"protected":"unprotected");
		printf("0x3FC000-0x3FDFFF: %s\n", bitval(bpr, 76)?"protected":"unprotected");
		printf("0x3FE000-0x3FFFFF: %s\n", bitval(bpr, 78)?"protected":"unprotected");

		printf("read locks:\n");
		printf("0x000000-0x001FFF: %s\n", bitval(bpr, 65)?"protected":"unprotected");
		printf("0x002000-0x003FFF: %s\n", bitval(bpr, 67)?"protected":"unprotected");
		printf("0x004000-0x005FFF: %s\n", bitval(bpr, 69)?"protected":"unprotected");
		printf("0x006000-0x007FFF: %s\n", bitval(bpr, 71)?"protected":"unprotected");
		printf("0x3F8000-0x3F9FFF: %s\n", bitval(bpr, 73)?"protected":"unprotected");
		printf("0x3FA000-0x3FBFFF: %s\n", bitval(bpr, 75)?"protected":"unprotected");
		printf("0x3FC000-0x3FDFFF: %s\n", bitval(bpr, 77)?"protected":"unprotected");
		printf("0x3FE000-0x3FFFFF: %s\n", bitval(bpr, 79)?"protected":"unprotected");
	}
}

void read_to_file(int fd, int start, int end, char *filename)
{
	int databytes = end - start;
	int numchunks = 1 + (databytes -1) / chunksize;
	if (verbose)
		printf("Transferring %d bytes in %d chunks of %d\n", databytes, numchunks, chunksize);

	// prepare tx buffer (we use the same buffer for tx and rx)
	uint8_t* buf = malloc(5 + chunksize);


	// prepare output file
	FILE * file = fopen(filename, "wb+");
	if (!file)
		pabort("could not open output file");


	int chunk;
	for (chunk=0 ; chunk<numchunks ; ++chunk)
	{
		int offset = start + chunk * chunksize;

		// calculate size of current chunk
		int thischunksize = databytes - offset;
		if (thischunksize > chunksize) thischunksize = chunksize;

		// we have to reset these every time
		// because they get overwritten every time
		buf[0] = 0x02; // select flash subsystem
		buf[1] = 0x03; // read command

		buf[2] = (offset >> 16) & 0xFF; // word 3 of addr
		buf[3] = (offset >>  8) & 0xFF; // word 2 of addr
		buf[4] = (offset      ) & 0xFF; // word 1 of addr
		transfer(fd, buf, buf, 5+thischunksize, false);

		int ret = fwrite(buf+5, 1, thischunksize, file);
		if (ret != thischunksize)
			pabort("not all bytes written to output file");

		// print progress:
		printf("\rProgress: %5.2f%%", 100.0 * chunk / numchunks);
		fflush(stdout);
	}
	fclose(file);
	free(buf);
	printf("\rProgress: done                                \n");
}

void verify_with_file(int fd, int start, int end, char * filename)
{
	// get file size:
	struct stat st;
	if (stat(filename, &st) != 0)
	{
		pabort("Failed to get file size");
	}
	int filesize = st.st_size;

	// write is truncated
	if (filesize > end - start)
		filesize = end - start;

	int numchunks = 1 + (filesize -1) / chunksize;

	// prepare tx buffer (we use the same buffer for tx and rx)
	uint8_t* spi_buf = malloc(5 + chunksize);
	uint8_t* file_buf = malloc(chunksize);

	// prepare output file
	FILE * file = fopen(filename, "rb");
	if (!file)
		pabort("could not open file again for verification step");


	int chunk;
	for (chunk=0 ; chunk<numchunks ; ++chunk)
	{
		int offset = start + chunk * chunksize;

		// calculate size of current chunk
		int thischunksize = filesize - chunk * chunksize;
		if (thischunksize > chunksize) thischunksize = chunksize;

		// we have to reset these every time
		// because they get overwritten every time
		spi_buf[0] = 0x02; // select flash subsystem
		spi_buf[1] = 0x03; // read command

		spi_buf[2] = (offset >> 16) & 0xFF; // word 3 of addr
		spi_buf[3] = (offset >>  8) & 0xFF; // word 2 of addr
		spi_buf[4] = (offset      ) & 0xFF; // word 1 of addr
		transfer(fd, spi_buf, spi_buf, 5+thischunksize, verbose);

		// read the same number of bytes from file
		int numread = fread(file_buf, 1, thischunksize, file);
		if (numread < thischunksize)
		{
			printf("\nError: File read failed at offset %d\n", offset);
		}

		if (memcmp(file_buf, spi_buf+5, thischunksize))
		{
			printf("Verification failed in chunk 0x%06X-0x%06X\n", offset, offset+thischunksize);
			if (verbose) {
				printf("raw spi data: \n");
				hex_dump(spi_buf+5, thischunksize, 32, "EEPROM");
				printf("file data: \n");
				hex_dump(file_buf, thischunksize, 32, "FILE");
			}
			abort();
		}

		// print progress:
		printf("\rVerifying: %5.2f%%", 100.0 * chunk / numchunks);
		fflush(stdout);
	}
	fclose(file);
	free(spi_buf);
	free(file_buf);
	printf("\nVerification complete                                \n");
}

void print_firmware_version(int fd)
{
	// prepare tx buffer (we use the same buffer for tx and rx)
	uint8_t* buf = malloc(2); // 1 select byte, 1 command byte, 10 response bytes for 80 block protection bits

	buf[0] = 0x07; // select version number
	buf[1] = 0x00; // empty space for result
	transfer(fd, buf, buf, 2, verbose);

	printf("Running firmware version: %d\n", buf[1]);
	free(buf);
}

void verify_block_protect_register(int fd)
{
	uint8_t bpr[10];

	// bpr[0] = bits 79:72
	// bpr[1] = bits 71:64
	// bpr[2] = bits 63:56
	// etc etc
	uint8_t target_bpr[10] = {0x55, 0x55, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

	uint8_t target_bpr_primary[10]  = {0x55, 0x00, 0xBF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFC, 0x00};
	uint8_t target_bpr_golden[10]   = {0x55, 0x55, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xE0, 0x03, 0xFF};
	uint8_t target_bpr_userdata[10] = {0x00, 0x55, 0x40, 0x00, 0x00, 0x00, 0x00, 0x1F, 0xFF, 0xFF};
	uint8_t target_bpr_jump[10]     = {0x15, 0x55, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};



	if (print_bpr || primary_input != NULL || golden_input != NULL || userdata_input != NULL || do_write_jump_addr)
	{
		// read the current BRP status
		read_block_protection_register(fd, bpr);
		if (print_bpr)
		{
			printf("Current block protection register:\n");
			print_block_protection_register(bpr);
		}

		// Calculate desireable BPR
		int i;
		for (i=0; i<10; i++)
		{
			if (primary_input != NULL)
				target_bpr[i] = target_bpr[i] & target_bpr_primary[i];
			if (golden_input!= NULL)
				target_bpr[i] = target_bpr[i] & target_bpr_golden[i];
			if (userdata_input != NULL)
				target_bpr[i] = target_bpr[i] & target_bpr_userdata[i];
			if (do_write_jump_addr)
				target_bpr[i] = target_bpr[i] & target_bpr_jump[i];
		}
		printf("Target block protection register:\n");
		print_block_protection_register(target_bpr);

		// determine if changes to bpr are needed
		bool tootight = false;
		bool tooloose = false;
		for (i=0; i<10; i++)
		{
			if (bpr[i] & ~target_bpr[i] != 0)
				tootight = true;
			bpr[i] = bpr[i] & target_bpr[i];
			if (bpr[i] != target_bpr[i])
				tooloose = true;
		}

		if (tooloose)
		{
			printf("warning: block protect register is not maximally tight!!\n");
		}
		if (tootight)
		{
			printf("Some block protection register bits need clearing. Writing new BPR:\n");
			print_block_protection_register(bpr);
			write_block_protection_register(fd, bpr);
		}
	}
}

int main(int argc, char* argv[])
{
	parse_opts(argc, argv);

	// open spi device
	int fd = open(device, O_RDWR);
	if (fd < 0)
		pabort("can't open device");
	setup_port(fd);

	// sanity check:
	if (primary_input && (primary_output || golden_output || chip_output || userdata_output))
	{
		printf("Refusing the read and write at the same time.\n");
		abort();
	}

	// print running firmware number
	if (print_firmwareid)
	{
		print_firmware_version(fd);
	}

	// check DIG_IFC_ENABLE and ask to enable
	verify_dig_ifc();

	// test connection by getting the spi flash id
	verify_chip_id(fd);

	// print and/or clear block protection register bits
	verify_block_protect_register(fd);


	// todo: abort if output file exists

	if (do_write_jump_addr)
	{
		write_jump_addr(fd);
	}

	// program flash:
	if (primary_input != NULL)
	{
		write_from_file( fd, PRIMARY_PATTERN_START, PRIMARY_PATTERN_END, primary_input);
		verify_with_file(fd, PRIMARY_PATTERN_START, PRIMARY_PATTERN_END, primary_input);
		printf("Upload complete. The new firmware will be loaded on the next power cycle.\n");
		printf("Execute slowc -P0x033f followed by slowc -P0x03ff to power-cycle the RD module.\n");
		printf("The version number of the running RD firmware can be checked with rd_flash -f\n");
	}
	if (golden_input != NULL)
	{
		write_from_file( fd, GOLDEN_PATTERN_START, GOLDEN_PATTERN_END, golden_input);
		verify_with_file(fd, GOLDEN_PATTERN_START, GOLDEN_PATTERN_END, golden_input);
		printf("Golden pattern upload complete.\n");
	}
	if (userdata_input != NULL)
	{
		write_from_file( fd, USER_DATA_START, USER_DATA_END, userdata_input);
		verify_with_file(fd, USER_DATA_START, USER_DATA_END, userdata_input);
		printf("Userdata upload complete.\n");
	}


	if (primary_output != NULL)
	{
		read_to_file(fd, PRIMARY_PATTERN_START, PRIMARY_PATTERN_END, primary_output);
	}
	if (golden_output != NULL)
	{
		read_to_file(fd, GOLDEN_PATTERN_START, GOLDEN_PATTERN_END, golden_output);
	}
	if (userdata_output != NULL)
	{
		read_to_file(fd, USER_DATA_START, USER_DATA_END, userdata_output);
	}
	if (chip_output!= NULL)
	{
		read_to_file(fd, PRIMARY_PATTERN_START, JUMP_COMMAND_END, chip_output);
	}

	close(fd);
    return 0;
}
