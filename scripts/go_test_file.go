package main

import (
    "fmt"
    "io"
    "io/fs"
    "os"
    "path/filepath"
    "sync"
    "time"
)

var (
    memory map[string][]byte
    mu     sync.Mutex
    wg     sync.WaitGroup
)

func main() {
    var files[]string

    err := filepath.WalkDir("./data_01", func(path string, d fs.DirEntry, err error) error {
        if !d.IsDir() {
           files = append(files, path)
        }
        return nil
    })
    if err != nil {
        fmt.Printf("Error reading directory: %v\n", err)
        return
    }

    memory = make(map[string][]byte)
    wg.Add(4)
    fileChan := make(chan string)
    for i := 0; i < 4; i++ {
        go func(num int) {
            defer wg.Done()

            for file := range fileChan {
                readFile(file)

                fmt.Printf("Content of file %s: Thread-%d \n", file, num)
            }
        }(i)
    }

    for _, file := range files {
        fileChan <- file
    }

    wg.Wait()
    fmt.Println("读取完毕")
    time.Sleep(6000 * time.Second)
}

func readFile(path string) {
    file, err := os.Open(path)
    if err != nil {
        return
    }
    defer file.Close()

    buf := make([]byte, 8191)
    var content []byte
    for {
        n, err := file.Read(buf)
        if err == io.EOF {
            break
        }
        if err != nil {
            return
        }
        content = append(content, buf[:n]...)
    }

    // 将文件内容保存到内存
    mu.Lock()
    memory[path] = content
    mu.Unlock()
}
