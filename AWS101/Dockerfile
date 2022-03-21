# https://hub.docker.com/_/microsoft-dotnet
FROM mcr.microsoft.com/dotnet/aspnet:6.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

# copy csproj and restore as distinct layers
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY ["AWS101.csproj", "AWS101/"]
RUN dotnet restore "AWS101/AWS101.csproj"

# copy and publish app and libraries
COPY . .
RUN dotnet restore "AWS101/AWS101.csproj"
WORKDIR "/src/AWS101"
RUN dotnet build "AWS101.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "AWS101.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
#COPY localhost.crt /usr/local/share/ca-certificates
#RUN chmod 644 /usr/local/share/ca-certificates/localhost.crt && update-ca-certificates
ENTRYPOINT ["dotnet", "AWS101.dll"]