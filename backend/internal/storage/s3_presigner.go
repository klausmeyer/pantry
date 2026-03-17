package storage

import (
	"context"
	"net/url"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	awscfg "github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-sdk-go-v2/service/s3/types"
	internalconfig "github.com/klausmeyer/pantry/backend/internal/config"
)

type S3Presigner struct {
	client        *s3.Client
	presignClient *s3.PresignClient
	bucket        string
}

func NewS3Presigner(ctx context.Context, cfg internalconfig.S3Config) (*S3Presigner, error) {
	awsCfg, err := awscfg.LoadDefaultConfig(
		ctx,
		awscfg.WithRegion(cfg.Region),
		awscfg.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(cfg.AccessKeyID, cfg.SecretAccessKey, "")),
		awscfg.WithEndpointResolverWithOptions(aws.EndpointResolverWithOptionsFunc(
			func(service, region string, _ ...any) (aws.Endpoint, error) {
				if cfg.Endpoint == "" {
					return aws.Endpoint{}, &aws.EndpointNotFoundError{}
				}
				return aws.Endpoint{
					URL:               cfg.Endpoint,
					HostnameImmutable: true,
				}, nil
			},
		)),
	)
	if err != nil {
		return nil, err
	}

	client := s3.NewFromConfig(awsCfg, func(options *s3.Options) {
		options.UsePathStyle = cfg.UsePathStyle
	})

	return &S3Presigner{
		client:        client,
		presignClient: s3.NewPresignClient(client),
		bucket:        cfg.Bucket,
	}, nil
}

func (p *S3Presigner) PresignPut(ctx context.Context, key, contentType string, expires time.Duration) (string, map[string]string, error) {
	input := &s3.PutObjectInput{
		Bucket:      aws.String(p.bucket),
		Key:         aws.String(key),
		ContentType: aws.String(contentType),
	}

	presigned, err := p.presignClient.PresignPutObject(ctx, input, func(options *s3.PresignOptions) {
		options.Expires = expires
	})
	if err != nil {
		return "", nil, err
	}

	return presigned.URL, map[string]string{
		"Content-Type": contentType,
	}, nil
}

func (p *S3Presigner) PresignGet(ctx context.Context, key string, expires time.Duration) (string, error) {
	input := &s3.GetObjectInput{
		Bucket: aws.String(p.bucket),
		Key:    aws.String(key),
	}

	presigned, err := p.presignClient.PresignGetObject(ctx, input, func(options *s3.PresignOptions) {
		options.Expires = expires
	})
	if err != nil {
		return "", err
	}

	return presigned.URL, nil
}

func (p *S3Presigner) Delete(ctx context.Context, key string) error {
	_, err := p.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(p.bucket),
		Key:    aws.String(key),
	})
	return err
}

func (p *S3Presigner) Copy(ctx context.Context, sourceKey, destKey string) error {
	copySource := url.PathEscape(p.bucket + "/" + sourceKey)
	_, err := p.client.CopyObject(ctx, &s3.CopyObjectInput{
		Bucket:            aws.String(p.bucket),
		Key:               aws.String(destKey),
		CopySource:        aws.String(copySource),
		MetadataDirective: types.MetadataDirectiveCopy,
	})
	return err
}
