/**
* Read-only memory mapping of a whole file.
*
* This replaces [mio](https://github.com/mandreyel/mio), the single header
* C++ library the original runner used, with the two system calls it was
* being asked for: map the file, hand back a slice of it, unmap it again.
* Mizu binaries are read once and never written, so nothing else mio offered
* is needed here.
*
* Note:
*   A zero length file is mapped as an empty slice rather than through
*   `mmap`, which rejects a length of zero.
*/
module mapped_file;

@nogc nothrow:

/**
* A file mapped into memory.
*
* `error` is null on success; otherwise `data` is empty and `error` describes
* what went wrong. Release the mapping with `unmapFile` either way.
*/
struct MappedFile {
	/// The file's contents.
	const(void)[] data;
	/// Why the mapping failed, or null if it did not.
	const(char)* error;

	version (Windows) {
		private void* fileHandle;
		private void* mappingHandle;
	} else {
		private size_t mappedLength;
	}
}

version (Windows) {

import core.sys.windows.winbase :
	CreateFileA, CreateFileMappingA, GetFileSizeEx, MapViewOfFile, UnmapViewOfFile,
	CloseHandle, INVALID_HANDLE_VALUE, OPEN_EXISTING;
import core.sys.windows.winnt :
	FILE_ATTRIBUTE_NORMAL, FILE_SHARE_READ, GENERIC_READ, LARGE_INTEGER, PAGE_READONLY;

private enum uint fileMapRead = 4; // FILE_MAP_READ

/**
* Maps `path` into memory for reading.
*
* Params:
*   path = null terminated path to the file to map
* Returns:
*   The mapping; check `error` before using `data`.
*/
MappedFile mapFile(const(char)* path) @trusted {
	MappedFile result;

	result.fileHandle = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, null,
		OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
	if (result.fileHandle is INVALID_HANDLE_VALUE) {
		result.fileHandle = null;
		result.error = "could not open the file";
		return result;
	}

	LARGE_INTEGER size;
	if (!GetFileSizeEx(result.fileHandle, &size)) {
		result.error = "could not measure the file";
		return result;
	}
	// An empty file has nothing to map, and CreateFileMapping rejects it.
	if (size.QuadPart == 0) return result;

	result.mappingHandle = CreateFileMappingA(result.fileHandle, null, PAGE_READONLY, 0, 0, null);
	if (result.mappingHandle is null) {
		result.error = "could not create a mapping of the file";
		return result;
	}

	auto view = MapViewOfFile(result.mappingHandle, fileMapRead, 0, 0, 0);
	if (view is null) {
		result.error = "could not map the file into memory";
		return result;
	}

	result.data = view[0 .. cast(size_t) size.QuadPart];
	return result;
}

/// Releases a mapping made by `mapFile`. Safe to call on a failed one.
void unmapFile(ref MappedFile file) @trusted {
	if (file.data.length) UnmapViewOfFile(cast(void*) file.data.ptr);
	if (file.mappingHandle !is null) CloseHandle(file.mappingHandle);
	if (file.fileHandle !is null) CloseHandle(file.fileHandle);
	file = MappedFile.init;
}

} else {

import core.stdc.errno : errno;
import core.stdc.string : strerror;
import core.sys.posix.fcntl : open, O_RDONLY;
import core.sys.posix.sys.mman : mmap, munmap, MAP_FAILED, MAP_PRIVATE, PROT_READ;
import core.sys.posix.sys.stat : fstat, stat_t;
import core.sys.posix.unistd : close;

/// Ditto
MappedFile mapFile(const(char)* path) @trusted {
	MappedFile result;

	immutable descriptor = open(path, O_RDONLY);
	if (descriptor < 0) {
		result.error = strerror(errno);
		return result;
	}
	// The mapping keeps the file alive on its own, so the descriptor is only
	// needed until `mmap` returns.
	scope(exit) close(descriptor);

	stat_t status;
	if (fstat(descriptor, &status) != 0) {
		result.error = strerror(errno);
		return result;
	}
	// An empty file has nothing to map, and `mmap` rejects a length of zero.
	if (status.st_size <= 0) return result;

	immutable length = cast(size_t) status.st_size;
	auto view = mmap(null, length, PROT_READ, MAP_PRIVATE, descriptor, 0);
	if (view is MAP_FAILED) {
		result.error = strerror(errno);
		return result;
	}

	result.data = view[0 .. length];
	result.mappedLength = length;
	return result;
}

/// Ditto
void unmapFile(ref MappedFile file) @trusted {
	if (file.mappedLength) munmap(cast(void*) file.data.ptr, file.mappedLength);
	file = MappedFile.init;
}

}
