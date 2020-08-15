package pkg

import (
	"fmt"
	"time"
)

// LogMessage consists of a timestamp and a message.
type LogMessage struct {
	ts      time.Time
	message string
}

// NewLogMessage returns a new LogMessage tagged with the current timestamp.
func NewLogMessage(m string) LogMessage {
	return LogMessage{
		ts:      time.Now(),
		message: m,
	}
}

func (lm LogMessage) String() string {
	return fmt.Sprintf("[%02d:%02d:%02d] %s", lm.ts.Hour(), lm.ts.Minute(), lm.ts.Second(), lm.message)
}
