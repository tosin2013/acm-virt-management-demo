package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const dataDir = "/data"
const staticDir = "/static"

type FileInfo struct {
	Name     string `json:"name"`
	Size     int64  `json:"size"`
	Modified string `json:"modified"`
	URL      string `json:"url"`
}

func main() {
	if err := os.MkdirAll(dataDir, 0775); err != nil {
		log.Fatalf("Cannot create data directory: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", handleHealthz)
	mux.HandleFunc("/api/files", handleListFiles)
	mux.HandleFunc("/api/upload", handleUpload)
	mux.HandleFunc("/api/delete/", handleDelete)
	mux.HandleFunc("/files/", handleServeFile)
	mux.HandleFunc("/", handleUI)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("httpd-fileserver listening on :%s (auth via oauth-proxy sidecar)", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func getServiceURL(r *http.Request) string {
	if url := os.Getenv("SERVICE_URL"); url != "" {
		return strings.TrimRight(url, "/")
	}
	return "http://" + r.Host
}

func handleHealthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func handleListFiles(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	entries, err := os.ReadDir(dataDir)
	if err != nil {
		http.Error(w, "failed to read directory", http.StatusInternalServerError)
		return
	}

	baseURL := getServiceURL(r)
	files := make([]FileInfo, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, FileInfo{
			Name:     info.Name(),
			Size:     info.Size(),
			Modified: info.ModTime().Format(time.RFC3339),
			URL:      baseURL + "/files/" + info.Name(),
		})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(files)
}

func handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	reader, err := r.MultipartReader()
	if err != nil {
		http.Error(w, "invalid multipart request", http.StatusBadRequest)
		return
	}

	for {
		part, err := reader.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			http.Error(w, "error reading multipart", http.StatusBadRequest)
			return
		}

		if part.FormName() != "file" {
			part.Close()
			continue
		}

		filename := filepath.Base(part.FileName())
		if filename == "" || filename == "." || filename == "/" {
			part.Close()
			http.Error(w, "invalid filename", http.StatusBadRequest)
			return
		}

		dst, err := os.Create(filepath.Join(dataDir, filename))
		if err != nil {
			part.Close()
			http.Error(w, "failed to create file", http.StatusInternalServerError)
			return
		}

		if _, err := io.Copy(dst, part); err != nil {
			dst.Close()
			part.Close()
			http.Error(w, "failed to write file", http.StatusInternalServerError)
			return
		}
		dst.Close()
		part.Close()
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func handleDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	name := filepath.Base(strings.TrimPrefix(r.URL.Path, "/api/delete/"))
	if name == "" || name == "." || name == "/" {
		http.Error(w, "invalid filename", http.StatusBadRequest)
		return
	}

	path := filepath.Join(dataDir, name)
	if _, err := os.Stat(path); os.IsNotExist(err) {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}

	if err := os.Remove(path); err != nil {
		http.Error(w, "failed to delete file", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "deleted", "name": name})
}

func handleServeFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	name := filepath.Base(strings.TrimPrefix(r.URL.Path, "/files/"))
	if name == "" || name == "." || name == "/" {
		http.Error(w, "invalid filename", http.StatusBadRequest)
		return
	}

	path := filepath.Join(dataDir, name)
	info, err := os.Stat(path)
	if os.IsNotExist(err) {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}

	ext := filepath.Ext(name)
	contentType := mime.TypeByExtension(ext)
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Length", fmt.Sprintf("%d", info.Size()))

	f, err := os.Open(path)
	if err != nil {
		http.Error(w, "failed to open file", http.StatusInternalServerError)
		return
	}
	defer f.Close()

	http.ServeContent(w, r, name, info.ModTime(), f)
}

func handleUI(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, filepath.Join(staticDir, "index.html"))
}
