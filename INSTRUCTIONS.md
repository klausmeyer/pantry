# Instructions

We are building an application called Pantry which will help people keeping track of their food supplies.

## Project Setup

The application consists of:

- An API specification written in OAS3
- A backend written in Go providing an API (following the JSON-API standard) for records stored inside a PostgreSQL database and files in an S3 bucket
- A frontend written in Angular for browsing and managing entries via the API

## Project Structure

- `./api` contains the api specification
- `./backend` contains the backend part of the application
- `./frontend` contains the frontend part of the application

## Data Model

### Items

- The main model will be representing an pantry item with the following attributes:
  - Name
  - Packaging (e.g. `can`, `box`, `bag`, `jar`, `other`)
  - Best before date
  - Content amount
  - Content unit (e.g. `grams`, `ml`, etc. - use metric system)
  - Picture
  - Comment (optional)
- Items can be available multiple times. We will have seperate records for them with some random, human redable unique identifier.
