package main

import (
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
)

func Heartbeat(c *gin.Context) {
	fmt.Println("Hello World by Gin!")
	c.JSON(http.StatusOK, gin.H{
		"message": "Heartbeat from gin!",
	})
}

func main() {
	r := gin.Default()
	r.GET("/ping", Heartbeat)
}
