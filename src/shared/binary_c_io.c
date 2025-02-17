/*
!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  8 . 0
!          --------------------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================
*/

// for large files
#define _FILE_OFFSET_BITS  64

#include "config.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

static int fd;

/* ----------------------------------------------------------------------------- */

void
FC_FUNC_(open_file_create,OPEN_FILE)(char *file) {
  fd = open(file, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd == -1) {
    fprintf(stderr, "Error opening file: %s exiting\n", file);
    exit(-1);
  }
}

void
FC_FUNC_(open_file_append,OPEN_FILE)(char *file) {
  fd = open(file, O_WRONLY | O_CREAT | O_APPEND, 0644);
  if (fd == -1) {
    fprintf(stderr, "Error opening file: %s exiting\n", file);
    exit(-1);
  }
}

void
FC_FUNC_(close_file,CLOSE_FILE)() {
  close(fd);
}

/* ----------------------------------------------------------------------------- */

void
FC_FUNC_(write_integer,WRITE_INTEGER)(int *z) {
  if (write(fd, z, sizeof(int)) == -1) {
    fprintf(stderr, "Error writing integer to file id: %d exiting\n", fd);
    exit(-1);
  }
}

void
FC_FUNC_(write_real,WRITE_REAL)(float *z) {
  if (write(fd, z, sizeof(float)) == -1) {
    fprintf(stderr, "Error writing real to file id: %d exiting\n", fd);
    exit(-1);
  }
}

void
FC_FUNC_(write_n_real,WRITE_N_REAL)(float *z,int *n) {
  if (write(fd, z, *n*sizeof(float)) == -1) {
    fprintf(stderr, "Error writing n real to file id: %d exiting\n", fd);
    exit(-1);
  }
}

void
FC_FUNC_(write_character,WRITE_CHARACTER)(char *z, int *lchar) {
  if (write(fd, z, *lchar*sizeof(char)) == -1) {
    fprintf(stderr, "Error writing character to file id: %d exiting\n", fd);
    exit(-1);
  }
}

/* ----------------------------------------------------------------------------- */

void
FC_FUNC_(open_file_fd,OPEN_FILE_FD)(char *file, int *pfd) {
  *pfd = open(file, O_WRONLY | O_CREAT, 0644);
  if (*pfd == -1) {
    fprintf(stderr, "Error opening file: %s exiting\n", file);
    exit(-1);
  }
}

void
FC_FUNC_(close_file_fd,CLOSE_FILE_FD)(int *pfd) {
  close(*pfd);
}

/* ----------------------------------------------------------------------------- */

void
FC_FUNC_(write_integer_fd,WRITE_INTEGER_FD)(int *pfd, int *z) {
  if (write(*pfd, z, sizeof(int)) == -1) {
    fprintf(stderr, "Error writing integer to file id: %d exiting\n", *pfd);
    exit(-1);
  }
}

void
FC_FUNC_(write_real_fd,WRITE_REAL_FD)(int *pfd, float *z) {
  if (write(*pfd, z, sizeof(float)) == -1) {
    fprintf(stderr, "Error writing real to file id: %d exiting\n", *pfd);
    exit(-1);
  }
}

void
FC_FUNC_(write_n_real_fd,WRITE_N_REAL_FD)(int *pfd, float *z,int *n) {
  if (write(*pfd, z, *n*sizeof(float)) == -1) {
    fprintf(stderr, "Error writing n real to file id: %d exiting\n", *pfd);
    exit(-1);
  }
}

void
FC_FUNC_(write_character_fd,WRITE_CHARACTER_FD)(int *pfd, char *z, int *lchar) {
  if (write(*pfd, z, *lchar*sizeof(char)) == -1) {
    fprintf(stderr, "Error writing character to file id: %d exiting\n", *pfd);
    exit(-1);
  }
}


/* ---------------------------------------

 IO performance test

 Software Optimization for High Performance Computing: Creating Faster Applications

 By Isom L. Crawford and Kevin R. Wadleigh
 Jul 18, 2003

 - uses functions fopen/fread/fwrite for binary file I/O

 --------------------------------------- */

//#define __USE_GNU  // has issues with gcc 5.5.x version? ".. error: unknown type name '__locale_t' .."
#include <string.h>

#define MIN(x,y) ((x) < (y) ? (x) : (y))

/* fastest performance on nehalem nodes:

Linux 2.6.18-164.11.1.el5 #1 SMP Wed Jan 20 10:04:55 EST 2010 x86_64 x86_64 x86_64 GNU/Linux

achieved with 16 KB buffers: */

//#define MAX_B 65536 // 64 KB
//#define MAX_B 32768 // 32 KB
#define MAX_B 16384 // 16 KB
//#define MAX_B 8192 // 8 KB

// absorbing files: instead of passing file descriptor, we use the array index
//                          first 0  - 3 indices for crust mantle files
//                          last 4   - 8 indices for outer core files
//                          index 9  - for NOISE_TOMOGRAPHY (SURFACE_MOVIE)
//                          index 10 - for topography file
//                          index 11 - for model files
#define ABS_FILEID 12

// file points
static FILE * fp_abs[ABS_FILEID];
// file work buffers
static char * work_buffer[ABS_FILEID];


void open_file_abs_r_fbin(int *fid, char *filename,int *length, long long *filesize) {
// opens file for read access

//This sequence assigns the MAX_B array work_buffer to the file pointer
// to be used for its buffering. performance should benefit.
  char * fncopy;
  char * blank;
  FILE *ft;
  int ret;

  // checks filesize
  if (*filesize == 0 ) {
    perror("Error file size for reading");
    exit(EXIT_FAILURE);
  }

  // Trim the file name.
  fncopy = strndup(filename, *length);
  blank = strchr(fncopy, ' ');
  if (blank != NULL) {
    fncopy[blank - fncopy] = '\0';
  }

  // opens file
  ft = fopen( fncopy, "rb" );
  if (ft == NULL ) {
    fprintf(stderr, "Error opening file: %s exiting\n", fncopy);
    perror("Error fopen in open_file_abs_r_fbin");
    exit(-1);
  }

  // sets mode for full buffering
  work_buffer[*fid] = (char *)malloc(MAX_B);
  ret = setvbuf( ft, work_buffer[*fid], _IOFBF, (size_t)MAX_B );
  if (ret != 0 ) {
    perror("Error setting working buffer");
    exit(EXIT_FAILURE);
  }

  // stores file index id fid: from 0 to 8
  fp_abs[*fid] = ft;

  free(fncopy);
}

void open_file_abs_w_fbin(int *fid, char *filename, int *length, long long *filesize) {
// opens file for write access

  //This sequence assigns the MAX_B array work_buffer to the file pointer
  // to be used for its buffering. performance should benefit.
  char * fncopy;
  char * blank;
  FILE *ft;
  int ret;

  // checks filesize
  if (*filesize == 0 ) {
    perror("Error file size for writing");
    exit(EXIT_FAILURE);
  }

  // Trim the file name.
  fncopy = strndup(filename, *length);
  blank = strchr(fncopy, ' ');
  if (blank != NULL) {
    fncopy[blank - fncopy] = '\0';
  }

  // opens file
  ft = fopen( fncopy, "wb+" );
  if (ft == NULL ) {
    fprintf(stderr, "Error opening file: %s exiting\n", fncopy);
    perror("Error fopen in open_file_abs_w_fbin");
    exit(-1);
  }

  // sets mode for full buffering
  work_buffer[*fid] = (char *)malloc(MAX_B);
  ret = setvbuf( ft, work_buffer[*fid], _IOFBF, (size_t)MAX_B );
  if (ret != 0 ) {
    perror("Error setting working buffer");
    exit(EXIT_FAILURE);
  }

  // stores file index id fid: from 0 to 8
  fp_abs[*fid] = ft;

  free(fncopy);
}

void close_file_abs_fbin(int * fid) {
// closes file

  fclose(fp_abs[*fid]);

  free(work_buffer[*fid]);

  fp_abs[*fid] = NULL;
  work_buffer[*fid] = NULL;
}

/* ----------------------------------------------------------------------------- */

void write_abs_fbin(int *fid, char *buffer, int *length, int *index) {
// writes binary file data in chunks of MAX_B
//
// note: index not used, data will be appended
  FILE *ft;
  int itemlen,remlen,donelen,ret;

  // file pointer
  ft = fp_abs[*fid];

  donelen = 0;
  remlen = *length;

  // writes items of maximum MAX_B to the file
  while (remlen > 0) {

    itemlen = MIN(remlen,MAX_B);
    ret = fwrite(buffer,1,itemlen,ft);
    if (ret > 0) {
      donelen = donelen + ret;
      remlen = remlen - MAX_B;
      buffer += MAX_B;
    }
    else{
      remlen = 0;
    }
  }
}

void write_abs_buffer_fbin(int *fid, char *buffer, int *length, int *index, int *unit_length) {
// writes binary file data in chunks of MAX_B
//
// note: index not used, data will be appended
//       unit_length not used as well
//       (given for similar function call as for write_abs_**_map() functions)
  FILE *ft;
  int itemlen,remlen,donelen,ret;

  // file pointer
  ft = fp_abs[*fid];

  donelen = 0;
  remlen = *length;

  // writes items of maximum MAX_B to the file
  while (remlen > 0) {

    itemlen = MIN(remlen,MAX_B);
    ret = fwrite(buffer,1,itemlen,ft);
    if (ret > 0) {
      donelen = donelen + ret;
      remlen = remlen - MAX_B;
      buffer += MAX_B;
    }
    else{
      remlen = 0;
    }
  }
}

/* ----------------------------------------------------------------------------- */

void read_abs_fbin(int *fid, char *buffer, int *length, int *index, int *shift) {
// reads binary file data in chunks of MAX_B

  FILE *ft;
  int ret,itemlen,remlen,donelen;
  long long pos;

  // file pointer
  ft = fp_abs[*fid];

  // positions file pointer (for reverse time access)
  pos = ((long long)*length) * (*index -1 ) + (*shift);

  ret = fseek(ft, pos , SEEK_SET);
  if (ret != 0 ) {
    perror("Error fseek");
    exit(EXIT_FAILURE);
  }

  donelen = 0;
  remlen = *length;

  // reads items of maximum MAX_B to the file
  while (remlen > 0) {

    // checks end of file
    if (ferror(ft) || feof(ft)) return;

    itemlen = MIN(remlen,MAX_B);
    ret = fread(buffer,1,itemlen,ft);

    if (ferror(ft) || feof(ft)) return;

    if (ret > 0) {
      donelen = donelen + ret;
      remlen = remlen - MAX_B;
      buffer += MAX_B;
    }
    else{
      remlen = 0;
    }
  }
}

void read_abs_buffer_fbin(int *fid, char *buffer, int *length, int *index, int *unit_length) {
// reads binary file data in chunks of MAX_B
//
// note: positioning the file head here uses strides of a given unit_length
//       (opposite to read_abs_fbin which assumes to have same unit_length and buffer length)

  FILE *ft;
  int ret,itemlen,remlen,donelen;
  long long pos;

  // file pointer
  ft = fp_abs[*fid];

  // positions file pointer (for reverse time access)
  pos = ((long long)*unit_length) * (*index -1 );

  ret = fseek(ft, pos , SEEK_SET);
  if (ret != 0 ) {
    perror("Error fseek");
    exit(EXIT_FAILURE);
  }

  donelen = 0;
  remlen = *length;

  // reads items of maximum MAX_B to the file
  while (remlen > 0) {

    // checks end of file
    if (ferror(ft) || feof(ft)) return;

    itemlen = MIN(remlen,MAX_B);
    ret = fread(buffer,1,itemlen,ft);

    if (ferror(ft) || feof(ft)) return;

    if (ret > 0) {
      donelen = donelen + ret;
      remlen = remlen - MAX_B;
      buffer += MAX_B;
    }
    else{
      remlen = 0;
    }
  }
}




/* ---------------------------------------

 IO performance test


A Performance Comparison of "read" and "mmap" in the Solaris 8 OS

By Oyetunde Fadele, September 2002

http://developers.sun.com/solaris/articles/read_mmap.html

or

High-performance network programming, Part 2: Speed up processing at both the client and server

by Girish Venkatachalam

http://www.ibm.com/developerworks/aix/library/au-highperform2/


 - uses functions mmap/memcpy for mapping file I/O

-------------------------------------  */


#include <errno.h>
#include <limits.h>
#include <sys/mman.h>

// file maps
static char * map_abs[ABS_FILEID];
// file descriptors
static int map_fd_abs[ABS_FILEID];
// file sizes
static long long filesize_abs[ABS_FILEID];

void open_file_abs_w_map(int *fid, char *filename, int *length, long long *filesize) {
// opens file for write access
  int ft;
  int result;
  char *map;
  char *fncopy;
  char *blank;

  // checks filesize
  if (*filesize == 0 ) {
    perror("Error file size for writing");
    exit(EXIT_FAILURE);
  }

  // Trim the file name.
  fncopy = strndup(filename, *length);
  blank = strchr(fncopy, ' ');
  if (blank != NULL) {
    fncopy[blank - fncopy] = '\0';
  }

  /* Open a file for writing.
   *  - Creating the file if it doesn't exist.
   *  - Truncating it to 0 size if it already exists. (not really needed)
   *
   * Note: "O_WRONLY" mode is not sufficient when mmaping.
   */
  ft = open(fncopy, O_RDWR | O_CREAT | O_TRUNC, (mode_t)0600);
  if (ft == -1) {
    fprintf(stderr, "Error opening file: %s exiting\n", fncopy);
    perror("Error opening file for writing");
    exit(EXIT_FAILURE);
  }

  // file index id fid: from 0 to 8
  map_fd_abs[*fid] = ft;

  free(fncopy);

  /* Stretch the file size to the size of the (mmapped) array of ints
   */
  filesize_abs[*fid] = *filesize;
  result = lseek(ft, filesize_abs[*fid] - 1, SEEK_SET);
  if (result == -1) {
    close(ft);
    perror("Error calling lseek() to 'stretch' the file");
    exit(EXIT_FAILURE);
  }

  /* Something needs to be written at the end of the file to
   * have the file actually have the new size.
   * Just writing an empty string at the current file position will do.
   *
   * Note:
   *  - The current position in the file is at the end of the stretched
   *    file due to the call to lseek().
   *  - An empty string is actually a single '\0' character, so a zero-byte
   *    will be written at the last byte of the file.
   */
  result = write(ft, "", 1);
  if (result != 1) {
    close(ft);
    perror("Error writing last byte of the file");
    exit(EXIT_FAILURE);
  }

  /* Now the file is ready to be mmapped.
   */
  map = mmap(0, filesize_abs[*fid], PROT_READ | PROT_WRITE, MAP_SHARED, ft, 0);
  if (map == MAP_FAILED) {
    close(ft);
    perror("Error mmapping the file");
    exit(EXIT_FAILURE);
  }

  map_abs[*fid] = map;
}

void open_file_abs_r_map(int *fid, char *filename,int *length, long long *filesize) {
  // opens file for read access
  char * fncopy;
  char * blank;
  int ft;
  char *map;

  // checks filesize
  if (*filesize == 0 ) {
    perror("Error file size for reading");
    exit(EXIT_FAILURE);
  }

  // Trim the file name.
  fncopy = strndup(filename, *length);
  blank = strchr(fncopy, ' ');
  if (blank != NULL) {
    fncopy[blank - fncopy] = '\0';
  }

  ft = open(fncopy, O_RDONLY);
  if (ft == -1) {
    fprintf(stderr, "Error opening file: %s exiting\n", fncopy);
    perror("Error opening file for reading");
    exit(EXIT_FAILURE);
  }

  // file index id fid: from 0 to 8
  map_fd_abs[*fid] = ft;

  free(fncopy);

  filesize_abs[*fid] = *filesize;

  map = mmap(0, filesize_abs[*fid], PROT_READ, MAP_SHARED, ft, 0);
  if (map == MAP_FAILED) {
    close(ft);
    perror("Error mmapping the file");
    exit(EXIT_FAILURE);
  }

  map_abs[*fid] = map;
}


void close_file_abs_map(int * fid) {
  /* Don't forget to free the mmapped memory
   */
  if (munmap(map_abs[*fid], filesize_abs[*fid]) == -1) {
    perror("Error un-mmapping the file");
    /* Decide here whether to close(fd) and exit() or not. Depends... */
  }

  /* Un-mmaping doesn't close the file, so we still need to do that.
   */
  close(map_fd_abs[*fid]);

  map_abs[*fid] = NULL;
  map_fd_abs[*fid] = 0;
  filesize_abs[*fid] = 0;
}

/* ----------------------------------------------------------------------------- */

void write_abs_map(int *fid, char *buffer, int *length , int *index) {
  char *map;
  long long offset;

  map = map_abs[*fid];

  // offset in bytes
  offset =  ((long long)*index -1 ) * (*length) ;

  // copies buffer to map
  memcpy( &map[offset], buffer, *length );
}

void write_abs_buffer_map(int *fid, char *buffer, int *length , int *index, int* unit_length) {
  char *map;
  long long offset;

  map = map_abs[*fid];

  // offset in bytes
  // uses strides of unit length
  offset =  ((long long)*index -1 ) * (*unit_length) ;

  // copies buffer to map
  memcpy( &map[offset], buffer, *length );
}

/* ----------------------------------------------------------------------------- */

void read_abs_map(int *fid, char *buffer, int *length , int *index, int *shift) {
  char *map;
  long long offset;

  map = map_abs[*fid];

  // offset in bytes
  offset =  ((long long)*index -1 ) * (*length) + (*shift);

  // copies map to buffer
  memcpy( buffer, &map[offset], *length );
}

void read_abs_buffer_map(int *fid, char *buffer, int *length , int *index, int *unit_length) {
  char *map;
  long long offset;

  map = map_abs[*fid];

  // offset in bytes
  // note: positioning uses strides of unit_length; buffer length can be larger than unit_length
  offset =  ((long long)*index -1 ) * (*unit_length) ;

  // copies map to buffer
  memcpy( buffer, &map[offset], *length );
}

/* ----------------------------------------------------------------------------- */

/*

wrapper functions

- for your preferred, optimized file i/o ;
  e.g. uncomment  // #define USE_MAP... in config.h to use mmap routines
         or comment out (default) to use fopen/fwrite/fread functions

 note: mmap functions should work fine for local harddisk directories, but can lead to
           problems with global (e.g. NFS) directories

  (on nehalem, Linux 2.6.18-164.11.1.el5 #1 SMP Wed Jan 20 10:04:55 EST 2010 x86_64 x86_64 x86_64 GNU/Linux
    - mmap functions are about 20 % faster than conventional fortran, unformatted file i/o
    - fwrite/fread function are about 12 % faster than conventional fortran, unformatted file i/o )

*/

void
FC_FUNC_(open_file_abs_w,OPEN_FILE_ABS_W)(int *fid, char *filename,int *length, long long *filesize)
{
#ifdef USE_MAP_FUNCTION
  open_file_abs_w_map(fid,filename,length,filesize);
#else
  open_file_abs_w_fbin(fid,filename,length,filesize);
#endif
}

void
FC_FUNC_(open_file_abs_r,OPEN_FILE_ABS_R)(int *fid, char *filename,int *length, long long *filesize)
{
#ifdef USE_MAP_FUNCTION
  open_file_abs_r_map(fid,filename,length,filesize);
#else
  open_file_abs_r_fbin(fid,filename,length,filesize);
#endif
}

void
FC_FUNC_(close_file_abs,CLOSE_FILES_ABS)(int *fid)
{
#ifdef USE_MAP_FUNCTION
  close_file_abs_map(fid);
#else
  close_file_abs_fbin(fid);
#endif
}

/* ----------------------------------------------------------------------------- */

// read/write wrappers
void
FC_FUNC_(write_abs,WRITE_ABS)(int *fid, char *buffer, int *length , int *index)
{
#ifdef USE_MAP_FUNCTION
  write_abs_map(fid,buffer,length,index);
#else
  write_abs_fbin(fid,buffer,length,index);
#endif
}

void
FC_FUNC_(read_abs,READ_ABS)(int *fid, char *buffer, int *length , int *index)
{
  int shift = 0;

#ifdef USE_MAP_FUNCTION
  read_abs_map(fid,buffer,length,index, &shift);
#else
  read_abs_fbin(fid,buffer,length,index, &shift);
#endif
}

void
FC_FUNC_(read_abs_shifted,READ_ABS_SHIFTED)(int *fid, char *buffer, int *length , int *index, int *shift)
{
#ifdef USE_MAP_FUNCTION
  read_abs_map(fid,buffer,length,index,shift);
#else
  read_abs_fbin(fid,buffer,length,index,shift);
#endif
}

// extra *_int function to read in real values
// note: MacOS compilation will complain if call read_abs_shifted(..) with an integer and real argument in same file...
//       thus, we add here this extra *_int function which can use the same function calls with a char* buffer argument as above.
//
//       by default, the call real_abs_shifted(..) in model_topo_bathy.f90 uses integer values to read in for topo/bathy values of integer*2
void
FC_FUNC_(read_abs_shifted_int,READ_ABS_SHIFTED_INT)(int *fid, char *buffer, int *length , int *index, int *shift)
{
#ifdef USE_MAP_FUNCTION
  read_abs_map(fid,buffer,length,index,shift);
#else
  read_abs_fbin(fid,buffer,length,index,shift);
#endif
}


/* ----------------------------------------------------------------------------- */

// buffered read/write wrappers
void
FC_FUNC_(write_abs_buffer,WRITE_ABS_BUFFER)(int *fid, char *buffer, int *length , int *index, int *unit_length)
{
#ifdef USE_MAP_FUNCTION
  write_abs_buffer_map(fid,buffer,length,index,unit_length);
#else
  write_abs_buffer_fbin(fid,buffer,length,index,unit_length);
#endif
}

void
FC_FUNC_(read_abs_buffer,READ_ABS_BUFFER)(int *fid, char *buffer, int *length , int *index, int *unit_length)
{
#ifdef USE_MAP_FUNCTION
  read_abs_buffer_map(fid,buffer,length,index,unit_length);
#else
  read_abs_buffer_fbin(fid,buffer,length,index,unit_length);
#endif
}


