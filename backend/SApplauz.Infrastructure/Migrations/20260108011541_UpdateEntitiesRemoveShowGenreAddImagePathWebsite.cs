using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SApplauz.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class UpdateEntitiesRemoveShowGenreAddImagePathWebsite : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Prvo obriši ShowGenres tabelu (uklanja FK constraintove)
            migrationBuilder.DropTable(
                name: "ShowGenres");

            // Ukloni TotalSeats iz Performances
            migrationBuilder.DropColumn(
                name: "TotalSeats",
                table: "Performances");

            // Ukloni City iz Institutions
            migrationBuilder.DropColumn(
                name: "City",
                table: "Institutions");

            // Dodaj Capacity u Institutions
            migrationBuilder.AddColumn<int>(
                name: "Capacity",
                table: "Institutions",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Dodaj ImagePath i Website u Institutions
            migrationBuilder.AddColumn<string>(
                name: "ImagePath",
                table: "Institutions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Website",
                table: "Institutions",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            // Dodaj GenreId u Shows (prvo bez FK constrainta)
            migrationBuilder.AddColumn<int>(
                name: "GenreId",
                table: "Shows",
                type: "int",
                nullable: false,
                defaultValue: 1);

            // Ako postoje postojeći Shows u bazi, postavi GenreId na prvi dostupan Genre (ID: 1)
            // Ako Genre sa ID 1 ne postoji, kreiraj ga privremeno
            migrationBuilder.Sql(@"
                IF NOT EXISTS (SELECT 1 FROM Genres WHERE Id = 1)
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM Genres WHERE Id = (SELECT MIN(Id) FROM Genres))
                    BEGIN
                        SET IDENTITY_INSERT Genres ON;
                        INSERT INTO Genres (Id, Name, CreatedAt)
                        VALUES (1, N'Temporary', GETUTCDATE());
                        SET IDENTITY_INSERT Genres OFF;
                    END
                END
                
                -- Postavi sve postojeće Shows na GenreId = 1 (ili prvi dostupan Genre)
                UPDATE Shows SET GenreId = ISNULL((SELECT MIN(Id) FROM Genres), 1) WHERE GenreId IS NULL OR GenreId = 0;
            ");

            // Dodaj ImagePath u Shows
            migrationBuilder.AddColumn<string>(
                name: "ImagePath",
                table: "Shows",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            // Kreiraj index i FK constraint za GenreId
            migrationBuilder.CreateIndex(
                name: "IX_Shows_GenreId",
                table: "Shows",
                column: "GenreId");

            migrationBuilder.AddForeignKey(
                name: "FK_Shows_Genres_GenreId",
                table: "Shows",
                column: "GenreId",
                principalTable: "Genres",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Shows_Genres_GenreId",
                table: "Shows");

            migrationBuilder.DropIndex(
                name: "IX_Shows_GenreId",
                table: "Shows");

            migrationBuilder.DropColumn(
                name: "GenreId",
                table: "Shows");

            migrationBuilder.DropColumn(
                name: "ImagePath",
                table: "Shows");

            migrationBuilder.DropColumn(
                name: "Capacity",
                table: "Institutions");

            migrationBuilder.DropColumn(
                name: "ImagePath",
                table: "Institutions");

            migrationBuilder.DropColumn(
                name: "Website",
                table: "Institutions");

            migrationBuilder.AddColumn<int>(
                name: "TotalSeats",
                table: "Performances",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "City",
                table: "Institutions",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ShowGenres",
                columns: table => new
                {
                    ShowId = table.Column<int>(type: "int", nullable: false),
                    GenreId = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ShowGenres", x => new { x.ShowId, x.GenreId });
                    table.ForeignKey(
                        name: "FK_ShowGenres_Genres_GenreId",
                        column: x => x.GenreId,
                        principalTable: "Genres",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ShowGenres_Shows_ShowId",
                        column: x => x.ShowId,
                        principalTable: "Shows",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ShowGenres_GenreId",
                table: "ShowGenres",
                column: "GenreId");
        }
    }
}
