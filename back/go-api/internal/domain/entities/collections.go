package entities

import (
	"time"
)

// Evento represents an event happening in the park.
type Evento struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	Titulo      string    `json:"titulo" validate:"required"`
	CapaURL     string    `json:"capa_url"`
	BannerURL   string    `json:"banner_url"`
	DataInicio  string    `json:"data_inicio"`
	DataFim     string    `json:"data_fim"`
	Local       string    `json:"local"`
	Horario     string    `json:"horario"`
	Conteudo    string    `json:"conteudo" gorm:"type:text"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Activity represents an activity ("Vem se divertir")
type Activity struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	Titulo      string    `json:"titulo"`
	Descricao   string    `json:"descricao" gorm:"type:text"`
	ImagemURL   string    `json:"imagem_url"`
	Local       string    `json:"local"`
	Horario     string    `json:"horario"`
	ParkID      uint      `json:"park_id"`
	Park        *Park     `json:"park,omitempty" gorm:"foreignKey:ParkID"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// MapPoint represents a geographic location pin inside a park
type MapPoint struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	Nome        string    `json:"nome"`
	Latitude    string    `json:"latitude"`
	Longitude   string    `json:"longitude"`
	ParkID      uint      `json:"park_id"`
	Park        *Park     `json:"park,omitempty" gorm:"foreignKey:ParkID"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Review represents a park review
type Review struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Titulo    string    `json:"titulo"`
	Rating    float64   `json:"rating"`
	Texto     string    `json:"texto" gorm:"type:text"`
	MidiaURL  string    `json:"midia_url"`
	ParkID    uint      `json:"park_id"`
	Park      *Park     `json:"park,omitempty" gorm:"foreignKey:ParkID"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// VemCaminhar represents a walking event
type VemCaminhar struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Titulo    string    `json:"titulo"`
	Slug      string    `json:"slug"`
	Descricao string    `json:"descricao" gorm:"type:text"`
	ImagemURL string    `json:"imagem_url"`
	Local     string    `json:"local"`
	Horario   string    `json:"horario"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Favorite represents a user's favorite activity or park
type Favorite struct {
	ID         uint      `json:"id" gorm:"primaryKey"`
	UserID     uint      `json:"user_id"`
	ActivityID *uint     `json:"activity_id"`
	Activity   *Activity `json:"activity,omitempty" gorm:"foreignKey:ActivityID"`
	ParkID     *uint     `json:"park_id"`
	Park       *Park     `json:"park,omitempty" gorm:"foreignKey:ParkID"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}
