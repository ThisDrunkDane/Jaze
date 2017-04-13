#import "fmt.odin";
#import "os.odin";
#import "strings.odin";
#import win32 "sys/windows.odin";
#import j32 "jaze_win32.odin";
#import asset "jaze_asset.odin";
#import gl "jaze_gl.odin";
#import stbi "stb_image.odin";

Err :: int;

ERR_SUCCESS        : Err : 0;
ERR_PATH_NOT_FOUND : Err : 1;
ERR_NO_FILES_FOUND : Err : 2;

Kind :: enum {
    Texture,
    Shader,
    Sound,
}

Catalog :: struct {
    Name : string,
    Path : string,
    FilesInFolder : int,
    test: int,
    Items : map[string]asset.Asset,
    AcceptedExtensions : [dynamic]string,
}

DebugInfo_t :: struct {
    NumberOfCatalogs : int,
    CatalogNames : [dynamic]string,
    Catalogs : [dynamic]^Catalog,
}

DebugInfo : DebugInfo_t;

CreateNew :: proc(kind : Kind, path : string, acceptedExtensions : string) -> (^Catalog, Err) {
    return CreateNew(kind, path, path, acceptedExtensions);
}

CreateNew :: proc(kind : Kind, identifier : string, path : string, acceptedExtensions : string) -> (^Catalog, Err) {
    res := new(Catalog);
    res.Name = identifier;
    buf := make([]byte, j32.MAX_PATH);
    res.Path = fmt.sprintf(buf[..0], "%s%s", path, path[len(path)-1] == '/' ? "" : "/");

    //Check if path exists
    pstr := strings.new_c_string(path); defer free(pstr);
    attr := j32.GetFileAttributes(pstr);
    if _IsDirectory(attr) {

        if acceptedExtensions != "" {
            strlen := len(acceptedExtensions);
            last := 0;
            for i := 0; i < strlen; i++ {
                if acceptedExtensions[i] == ',' {
                    append(res.AcceptedExtensions, acceptedExtensions[last..i]);
                    last = i+1;
                }

                if i == strlen-1 {
                    append(res.AcceptedExtensions, acceptedExtensions[last..i+1]);
                }
            } 
        }

        data := j32.FindData{};
        fmt.sprintf(buf[..0], "%s%s", path, path[len(path)-1] == '\\' ? "*" : "\\*");
        fileH := j32.FindFirstFile(^buf[0], ^data);
        res.FilesInFolder++;
        if fileH != win32.INVALID_HANDLE {
            for j32.FindNextFile(fileH, ^data) == win32.TRUE {
                nameBuf := make([]byte, len(data.FileName));
                copy(nameBuf, data.FileName[..]);
                str := strings.to_odin_string(^nameBuf[0]);
                for ext in res.AcceptedExtensions {
                    if _GetFileExtension(str) == ext {
                        file := asset.FileInfo_t{};
                        file.Name = _GetFileNameWithoutExtension(str);
                        pathBuf := make([]byte, j32.MAX_PATH);
                        file.Path = fmt.sprintf(pathBuf[..0], "%s%s", res.Path, str);


                        match kind {
                            case Kind.Texture : {
                                asset := asset.Asset.Texture{};
                                c_str := strings.new_c_string(file.Path); defer free(c_str);
                                stbi.info(c_str, ^asset.Width, ^asset.Height, ^asset.Comp);
                                asset.FileInfo = file;
                                res.Items[file.Name] = asset;
                                res.test++;
                            }

                            case Kind.Shader : {
                                asset := asset.Asset.Shader{};
                                asset.FileInfo = file;
                                asset.LoadedFromDisk = true;

                                data, _ := os.read_entire_file(asset.FileInfo.Path);
                                asset.Source = strings.to_odin_string(^data[0]);

                                match ext {
                                    case ".vs" : {
                                        asset.Type = gl.ShaderTypes.Vertex;
                                    }

                                    case ".fs" : {
                                        asset.Type = gl.ShaderTypes.Fragment;
                                    }
                                }

                                res.Items[file.Name] = asset;
                                res.test++;
                            }
                        }

                        break;
                    }
                }
                res.FilesInFolder++;
            }
        } else {
            return nil, ERR_NO_FILES_FOUND;
        }

    } else {
        return nil, ERR_PATH_NOT_FOUND;
    }

    DebugInfo.NumberOfCatalogs++;
    append(DebugInfo.CatalogNames, res.Name);
    append(DebugInfo.Catalogs, res);
    return res, ERR_SUCCESS;
}

Find :: proc(catalog : ^Catalog, filename : string) -> (any, Err) {
    return nil, ERR_SUCCESS;
}

//Util
_GetFileExtension :: proc(filename : string) -> string {
    strLen := len(filename);

    for i := strLen-1; i > 0; i-- {
        if filename[i] == '.' {
            res := filename[i..strLen];
            if res == "." {
                return "";
            } else {
                return res;
            }
        }
    }

    return "";
}

_GetFileNameWithoutExtension :: proc(filename : string) -> string {
    extlen := len(_GetFileExtension(filename));
    namelen := len(filename);
    return filename[..(namelen-extlen)];
}

_IsDirectory :: proc(attr : u32) -> bool {
   return (cast(i32)attr != j32.INVALID_FILE_ATTRIBUTES) && 
          ((attr & j32.FILE_ATTRIBUTE_DIRECTORY) == j32.FILE_ATTRIBUTE_DIRECTORY);
}
