/**
* Read-only memory mapping of a whole file: map it, hand back a slice of it, unmap it again. Mizu binaries are read once and never written, so nothing more is needed.
*/
module mapped_file;

@nogc nothrow:

/// A file mapped into memory; release it with `unmapFile`, whether or not the mapping succeeded.
struct MappedFile {
	/// The file's contents; empty for an empty file or a failed mapping.
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

import core.sys.windows.winbase : CreateFileA, CreateFileMappingA, GetFileSizeEx, MapViewOfFile, UnmapViewOfFile, CloseHandle, INVALID_HANDLE_VALUE, OPEN_EXISTING;
import core.sys.windows.winnt : FILE_ATTRIBUTE_NORMAL, FILE_SHARE_READ, GENERIC_READ, LARGE_INTEGER, PAGE_READONLY;

private enum uint fileMapRead = 4; // FILE_MAP_READ

/**
* Maps the file at `path` into memory for reading.
*
* An empty file is returned as an empty `data` without being mapped, since the system calls reject a length of zero.
*
* Params:
*   path = null-terminated path to the file to map
* Returns: the mapping; on failure `error` says why and `data` is empty.
*
* Examples:
* ---
* auto file = mapFile("no such file.mizu");
* scope(exit) unmapFile(file);
* assert(file.error !is null);
* assert(file.data.length == 0);
* ---
*/
MappedFile mapFile(const(char)* path) @trusted {
	MappedFile result;

	result.fileHandle = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
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

/**
* Releases a mapping made by `mapFile`, including a failed one, and resets `file` to `MappedFile.init`.
*
* Examples:
* ---
* auto file = mapFile("no such file.mizu");
* unmapFile(file);
* assert(file.error is null);
* ---
*/
void unmapFile(ref MappedFile file) @trusted {
	// Nothing useful can be done about a handle that will not close.
	if (file.data.length) cast(void) UnmapViewOfFile(cast(void*) file.data.ptr);
	if (file.mappingHandle !is null) cast(void) CloseHandle(file.mappingHandle);
	if (file.fileHandle !is null) cast(void) CloseHandle(file.fileHandle);
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
	// The mapping keeps the file alive on its own, so the descriptor is only needed until `mmap` returns.
	scope(exit) cast(void) close(descriptor);

	stat_t status;
	if (fstat(descriptor, &status) != 0) {
		result.error = strerror(errno);
		return result;
	}
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
	// `munmap` fails only for an address it never mapped, which `mappedLength` rules out.
	if (file.mappedLength) cast(void) munmap(cast(void*) file.data.ptr, file.mappedLength);
	file = MappedFile.init;
}

}
