package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"time"

	"github.com/kwkoo/configparser"
	"github.com/kwkoo/webnotifications"
)

func main() {
	config := struct {
		Port       int    `usage:"HTTP listener port" default:"8080"`
		DocRoot    string `usage:"HTML document root" mandatory:"true"`
		BufferSize int    `usage:"Number of notifications to keep" default:"10"`
	}{}

	if err := configparser.Parse(&config); err != nil {
		log.Fatal(err)
	}

	// todo: Init buffer and channels here

	wh := webnotifications.InitWebHandler(config.DocRoot, webnotifications.InitHub(config.BufferSize))

	// Setup signal handling.
	shutdown := make(chan os.Signal)
	signal.Notify(shutdown, os.Interrupt)

	var wg sync.WaitGroup
	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", config.Port),
		Handler: wh,
	}
	go func() {
		log.Printf("listening on port %v", config.Port)
		wg.Add(1)
		defer wg.Done()
		if err := server.ListenAndServe(); err != nil {
			if err == http.ErrServerClosed {
				log.Print("web server graceful shutdown")
				return
			}
			log.Fatal(err)
		}
	}()

	// Wait for SIGINT
	<-shutdown
	log.Print("interrupt signal received, initiating web server shutdown...")
	signal.Reset(os.Interrupt)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	server.Shutdown(ctx)

	wg.Wait()
	log.Print("Shutdown successful")

	//log.Printf("Listening on port %v", config.Port)

	/*
		http.HandleFunc(credentialsURI, getCredentials)
		http.HandleFunc(adminURI, admin)
		http.Handle("/", http.FileServer(http.Dir(config.DocRoot)))
		log.Fatal(http.ListenAndServe(fmt.Sprintf(":%d", config.Port), nil))
	*/
}
